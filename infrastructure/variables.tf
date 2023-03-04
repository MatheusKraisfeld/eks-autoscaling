variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account" {
  default = "741358071637"
}

variable "project_name" {
  default = "eks-autoscaling"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-autoscaling"
}
