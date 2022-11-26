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
  default = "eks-flux"
}

variable "branch" {
  default = "main"
}

variable "target_path" {
  default = "apps/"
}

variable "flux_token" {
  default = ""
}
