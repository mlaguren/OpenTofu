variable "role_name" {
  description = "IAM role name to create"
  type        = string
}

variable "description" {
  description = "Description for the IAM role"
  type        = string
  default     = "Reusable Developer Role (least-priv baseline, extensible)"
}

variable "permissions_boundary_arn" {
  description = "Optional IAM permissions boundary ARN. Use null to skip."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the IAM role"
  type        = map(string)
  default     = {}
}

variable "managed_policy_arns" {
  description = "Managed policy ARNs (AWS or customer-managed) to attach to the role"
  type        = list(string)
  default     = []
}

variable "inline_policies_json" {
  description = "Map of name => JSON policy documents (already jsonencoded)"
  type        = map(string)
  default     = {}
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in this AWS account"
  type        = string
}

variable "github_repo_sub_patterns" {
  description = <<EOT
Allowed GitHub 'sub' patterns for OIDC, e.g.:
- ["repo:mlaguren/OpenTofu:*"]
- ["repo:org/repo:ref:refs/heads/main"]
EOT
  type    = list(string)
  default = []
}

variable "additional_trusted_principals" {
  description = "Optional AWS principals (user/role ARNs) allowed to AssumeRole for local testing"
  type        = list(string)
  default     = []
}
