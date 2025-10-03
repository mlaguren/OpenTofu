terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Example: permissions boundary that caps what the role can ever do
data "aws_iam_policy_document" "permissions_boundary" {
  statement {
    sid       = "DenyEverythingByDefault"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    # Tip: invert this with "Deny" + NotAction for carve-outs, or instead attach a boundary that ALLOWS only specific services.
  }
}

resource "aws_iam_policy" "dev_boundary" {
  name   = "dev-permissions-boundary"
  policy = data.aws_iam_policy_document.permissions_boundary.json
}

# Minimal inline policy example (read-only to STS and IAM Get* needed by some SDKs)
# tflint-ignore: terraform_unused_declarations
data "aws_iam_policy_document" "baseline_readonly" {
  statement {
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

module "iam_developer_role" {
  source = "../../modules/iam-developer-role"

  role_name   = "dev-role"
  description = "Reusable Developer Role (least-priv baseline, extensible)"

  # ⚠️ For the test run, skip boundary or use a permissive test boundary
  permissions_boundary_arn = null

  tags = {
    Env     = "dev"
    Owner   = "Platform"
    Project = "OpenTofu"
  }

  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_repo_sub_patterns = var.github_repo_sub_patterns

  # ✅ Allow your local user (or a role/group you use locally) to assume the role in tests
  additional_trusted_principals = [
    "arn:aws:iam::252371519482:user/melvin.laguren@fabrion.com"
  ]

  # If your module outputs role_arn, you can reference it below for the user policy
}

# If your module outputs role_arn, use it directly. Otherwise hardcode the ARN.
# output "role_arn" from the module is recommended.

resource "aws_iam_user_policy" "allow_assume_dev_role" {
  user = "melvin.laguren@fabrion.com"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "sts:AssumeRole",
      Resource = "arn:aws:iam::252371519482:role/dev-role" # or module.iam_developer_role.role_arn
    }]
  })
}

