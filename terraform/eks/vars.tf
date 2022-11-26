# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = "eks-gitops-devsec"
}

variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "github_owner" {
  default = "iagobanov"
}

variable "repository_name" {
  default = "flux-eks"
}

variable "branch" {
  default = "main"
}

variable "flux_token" {
  default = "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"
}
