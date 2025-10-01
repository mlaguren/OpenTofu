terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Trust policy for GitHub OIDC minting short-lived creds
  oidc_trust = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Allow specific repos/branches/tags via 'sub' matches
          StringLike = length(var.github_repo_sub_patterns) > 0 ? {
            "token.actions.githubusercontent.com:sub" = var.github_repo_sub_patterns
          } : null
        }
      }
    ]
  }
}

resource "aws_iam_role" "dev" {
  name                 = var.role_name
  description          = var.description
  assume_role_policy   = jsonencode(local.oidc_trust)
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

# Attach any number of managed policies (AWS or customer-managed)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.dev.name
  policy_arn = each.value
}

# Optional inline policies
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
