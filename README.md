# OpenTofu Infrastructure Setup

This repository contains Infrastructure-as-Code (IaC) definitions for provisioning and managing AWS resources using OpenTofu.

The goal is to establish a reusable, modular foundation for cloud infrastructure across environments (dev, int, prod), covering IAM roles, security policies, S3/Iceberg data lake, EKS clusters, and related services.

# Features

## IAM & Security Policies

* Developer IAM roles with least-privilege access
* GitHub OIDC integration for secure CI/CD pipelines

## Data Lake (S3 + Iceberg)

* S3 buckets provisioned for Iceberg tables
* Glue catalog integration for Athena queries

## EKS Cluster Foundation

* Modular setup for Kubernetes workloads
* Environment-specific overlays for dev, int, and prod

# Getting Started
## Prerequisites

* OpenTofu (brew install opentofu)
* tflint
* tfsec
* Golang (for Terratest)

## Clone The Repository
```
git clone https://github.com/mlaguren/OpenTofu.git
cd OpenTofu
```

## Initialize OpenTofu
```bash
tofu init
```

# Linting & Security

## Check Formatting
```bash
tofu fmt -check -recursive
```

## Linting
```bash
tflint --recursive
```

## Security
```bash
tfsec
```

# Unit Testing
Terratest is used to validate OpenTofu modules.

## Set Up (Local)
Before tests can be executed locally, you must set up your environment in one of the following options.

### Option 1
Using a profile
```bash
export AWS_PROFILE=dev
export AWS_REGION=us-east-1
aws sso login --profile dev   # if your profile uses SSO
# or: aws configure --profile dev
```

### Option 2
Using keys (not recommended for long time usage)
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # only if using temporary creds
export AWS_REGION=us-east-1
```

## Additional Variables
### CI Like Runs
Set the following variables:

```bash
export TF_INPUT=false
export TF_IN_AUTOMATION=1
# (optional) speed up init in repeat runs:
export TF_CLI_ARGS_init="-upgrade=false -lock=false"
```

### Common Modules
```bash
export TF_VAR_environment=dev
export TF_VAR_role_name=developer
export TF_VAR_tags='{"project":"OpenTofu","owner":"platform"}'
# If your tests need account id or ARNs:
export DEV_ACCOUNT_ID=123456789012
```

## Check authentication
```bash
aws sts get-caller-identity   # or: aws sts get-caller-identity --profile dev
```

## Using .env file
Create a .env.local-testing
```bash
# Auth – choose one style
AWS_PROFILE=dev
AWS_REGION=us-east-1
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_SESSION_TOKEN=

# OpenTofu / Test
TF_INPUT=false
TF_IN_AUTOMATION=1
TF_CLI_ARGS_init=-upgrade=false -lock=false

# Module inputs (edit to match your vars)
TF_VAR_environment=dev
TF_VAR_role_name=developer
TF_VAR_tags={"project":"OpenTofu","owner":"platform"}

# Test helpers
DEV_ACCOUNT_ID=123456789012
```

Load the env file:
```bash
set -a; source .env.local-test; set +a
```

## Running tests
go install gotest.tools/gotestsum@latest
To run a single test:
```bash
cd tests
go test -run TestIamDeveloperRole -v -timeout 30m
```

To run test suite:
```bash
cd tests
go test -v ./...
```


