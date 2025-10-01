package test

import (
	"context"
	"errors"
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
	accountID := mustGetenv(t, "AWS_ACCOUNT_ID") // used in var below

	unique := random.UniqueId()
	tfOpts := &terraform.Options{
		TerraformDir:   "../envs/dev",
		TerraformBinary: "tofu", // ensure Terratest invokes OpenTofu, not Terraform
		Vars: map[string]interface{}{
			"aws_region":                  awsRegion,
			"github_oidc_provider_arn":    "arn:aws:iam::" + accountID + ":oidc-provider/token.actions.githubusercontent.com",
			"github_repo_sub_patterns":    []string{"repo:dummy-org/dummy-repo:*"},
		},
		NoColor: true,
		EnvVars: map[string]string{
			"AWS_REGION": awsRegion,
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

	// Load default creds (from your dev env or CI execution role)
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		t.Fatalf("load cfg: %v", err)
	}

	// Assume the newly created role
	stsClient := sts.NewFromConfig(cfg)
	roleProvider := stscreds.NewAssumeRoleProvider(stsClient, roleArn, func(o *stscreds.AssumeRoleOptions) {
		o.RoleSessionName = "terratest-" + unique
		o.Duration = 15 * time.Minute
	})

	assumedCfg := cfg
	assumedCfg.Credentials = aws.NewCredentialsCache(roleProvider)
	assumedSts := sts.NewFromConfig(assumedCfg)

	// Prove we can call STS as the assumed role
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
