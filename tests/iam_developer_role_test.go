package test

import (
	"context"
	"errors"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	smithy "github.com/aws/smithy-go"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestIamDeveloperRole(t *testing.T) {
	t.Parallel()

	awsRegion := getenvDefault("AWS_REGION", "us-east-1")
	accountID := mustGetenv(t, "AWS_ACCOUNT_ID") // provided by workflow step

	unique := random.UniqueId()
	tfOpts := &terraform.Options{
		TerraformDir:    "../envs/dev",
		TerraformBinary: "tofu", // ensure Terratest invokes OpenTofu, not Terraform
		Vars: map[string]interface{}{
			"aws_region":               awsRegion,
			"github_oidc_provider_arn": fmt.Sprintf("arn:aws:iam::%s:oidc-provider/token.actions.githubusercontent.com", accountID),
			"github_repo_sub_patterns": []string{"repo:dummy-org/dummy-repo:*"},
			// ensure your envs/dev/main.tf wires additional_trusted_principals for local runs
		},
		NoColor: true,

		// IMPORTANT: pass the OIDC credentials & region to the Terraform subprocess
		EnvVars: map[string]string{
			"AWS_REGION":            awsRegion,
			"AWS_DEFAULT_REGION":    awsRegion,
			"AWS_ACCESS_KEY_ID":     os.Getenv("AWS_ACCESS_KEY_ID"),
			"AWS_SECRET_ACCESS_KEY": os.Getenv("AWS_SECRET_ACCESS_KEY"),
			"AWS_SESSION_TOKEN":     os.Getenv("AWS_SESSION_TOKEN"),
		},

		MaxRetries:         1,
		TimeBetweenRetries: 0,
	}

	defer terraform.Destroy(t, tfOpts)
	terraform.InitAndApply(t, tfOpts)

	roleArn := terraform.Output(t, tfOpts, "developer_role_arn")
	if roleArn == "" {
		t.Fatalf("expected role ARN output, got empty")
	}

	// Load default creds (should be the OIDC-assumed role)
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		t.Fatalf("load cfg: %v", err)
	}

	// Wait for IAM eventual consistency
	waitUntilAssumable(t, cfg, roleArn)

	// Assume the just-created developer role
	stsClient := sts.NewFromConfig(cfg)
	roleProvider := stscreds.NewAssumeRoleProvider(stsClient, roleArn, func(o *stscreds.AssumeRoleOptions) {
		o.RoleSessionName = "terratest-" + unique
		o.Duration = 15 * time.Minute
	})

	assumedCfg := cfg
	assumedCfg.Credentials = aws.NewCredentialsCache(roleProvider)
	assumedSts := sts.NewFromConfig(assumedCfg)

	// Prove STS works under assumed role
	idOut, err := assumedSts.GetCallerIdentity(context.Background(), &sts.GetCallerIdentityInput{})
	if err != nil {
		var ae smithy.APIError
		if errors.As(err, &ae) {
			t.Fatalf("GetCallerIdentity failed: %s - %s", ae.ErrorCode(), ae.ErrorMessage())
		}
		t.Fatalf("GetCallerIdentity failed: %v", err)
	}
	if idOut.Arn == nil || *idOut.Arn == "" {
		t.Fatalf("expected non-empty caller identity ARN")
	}
}

func waitUntilAssumable(t *testing.T, cfg aws.Config, roleArn string) {
	t.Helper()
	client := sts.NewFromConfig(cfg)

	backoffs := []time.Duration{
		2 * time.Second,
		4 * time.Second,
		8 * time.Second,
		16 * time.Second,
	}

	var lastErr error
	for i, d := range backoffs {
		_, err := client.AssumeRole(context.Background(), &sts.AssumeRoleInput{
			RoleArn:         aws.String(roleArn),
			RoleSessionName: aws.String(fmt.Sprintf("probe-%d", time.Now().Unix())),
			DurationSeconds: aws.Int32(900),
		})
		if err == nil {
			return // role is assumable now
		}
		lastErr = err
		t.Logf("AssumeRole not ready yet (attempt %d/%d): %v; sleeping %s", i+1, len(backoffs), err, d)
		time.Sleep(d)
	}
	t.Fatalf("AssumeRole failed after retries: %v", lastErr)
}

func mustGetenv(t *testing.T, k string) string {
	v := os.Getenv(k)
	if v == "" {
		t.Fatalf("missing required env var %s", k)
	}
	return v
}

func getenvDefault(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
