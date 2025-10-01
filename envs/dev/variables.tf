variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_oidc_provider_arn" {
  type = string
}

variable "github_repo_sub_patterns" {
  type    = list(string)
  default = ["repo:yourorg/yourrepo:*"] # tighten per repo/branch/tag as needed
}
