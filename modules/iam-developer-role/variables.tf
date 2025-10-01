variable "role_name" {
  type        = string
  description = "Name of the developer role"
}

variable "description" {
  type    = string
  default = "Reusable Developer Role (least-priv baseline, extensible)"
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "ARN of the GitHub OIDC provider in this AWS account, e.g. arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com"
}

variable "github_repo_sub_patterns" {
  type        = list(string)
  description = "Allowed GitHub repo sub patterns, e.g. [\"repo:yourorg/yourrepo:*\", \"repo:yourorg/other:*\" ]"
  default     = []
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "Optional AWS managed or customer managed policies to attach"
  default     = []
}

variable "inline_policies_json" {
  type        = map(string)
  default     = {}
  description = "Map of { policy_name = json } for inline policies"
}

variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Optional permissions boundary ARN to enforce least-priv guardrails"
}

variable "tags" {
  type    = map(string)
  default = {}
}
