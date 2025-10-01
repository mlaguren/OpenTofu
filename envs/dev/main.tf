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
data "aws_iam_policy_document" "baseline_readonly" {
  statement {
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

module "iam_developer_role" {
  source = "../../modules/iam-developer-role"

  role_name                = "dev-role"
  description              = "Reusable Developer Role (least-priv baseline, extensible)"
  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_repo_sub_patterns = var.github_repo_sub_patterns

  permissions_boundary_arn = aws_iam_policy.dev_boundary.arn

  # Start with no broad permissions; add Iceberg/EKS/etc. later in other epics
  managed_policy_arns = [] # e.g., ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  inline_policies_json = {
    "baseline" = data.aws_iam_policy_document.baseline_readonly.json
  }

  tags = {
    Project = "OpenTofu"
    Env     = "dev"
    Owner   = "Platform"
  }
}
