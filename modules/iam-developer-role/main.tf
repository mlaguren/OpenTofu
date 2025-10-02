terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------- Locals ----------
locals {
  # Always-present piece of the OIDC condition
  oidc_condition_base = {
    StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
  }

  # Only add StringLike when repo sub patterns are provided
  oidc_condition_extra = length(var.github_repo_sub_patterns) > 0 ? {
    StringLike = { "token.actions.githubusercontent.com:sub" = var.github_repo_sub_patterns }
  } : {}

  # Final OIDC condition has consistent shape (StringLike present only if non-empty)
  oidc_condition = merge(local.oidc_condition_base, local.oidc_condition_extra)

  # OIDC trust (no branch here, so types never mismatch)
  oidc_trust = {
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = local.oidc_condition
    }]
  }

  # Optional local assume-role statement (sts:AssumeRole) for user/role ARNs
  local_trusted_statement = length(var.additional_trusted_principals) > 0 ? [{
    Effect    = "Allow"
    Principal = { AWS = var.additional_trusted_principals }
    Action    = "sts:AssumeRole"
  }] : []

  # Final trust policy combines OIDC and optional local trust
  trust_policy = {
    Version   = "2012-10-17"
    Statement = concat(local.oidc_trust.Statement, local.local_trusted_statement)
  }
}

# ---------- IAM Role ----------
resource "aws_iam_role" "dev" {
  name                 = var.role_name
  description          = var.description
  assume_role_policy   = jsonencode(local.trust_policy)
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

# Attach any number of managed policies (AWS or customer-managed)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.dev.name
  policy_arn = each.value
}

# Optional inline policies (create as managed customer policies, then attach)
resource "aws_iam_policy" "inline_src" {
  for_each = var.inline_policies_json
  name     = "${var.role_name}-${each.key}"
  policy   = each.value
}

resource "aws_iam_role_policy_attachment" "inline_attach" {
  for_each   = aws_iam_policy.inline_src
  role       = aws_iam_role.dev.name
  policy_arn = each.value.arn
}
