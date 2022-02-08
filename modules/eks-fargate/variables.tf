variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "environment" {
  type = string
}

## Karpenter variable
variable "karpenter_namespace" {
  type = string
}

variable "karpenter_serviceaccount" {
  type = string
}

variable "karpenter_iam_instance_profile" {
  type = string
}
