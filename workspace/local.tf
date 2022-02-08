locals {
  cluster_name    = "sandbox"
  cluster_version = "1.21"
  region          = "us-east-2"
  environment     = "develop"

  instance_types = ["t3.medium", "t3a.medium"]

  ## Karpenter variables
  karpenter_chart_version              = "v0.6.1"
  karpenter_iam_instance_profile_name  = "KarpenterIamInstanceProfile"
  k8s_service_karpenter_namespace      = "karpenter"
  k8s_service_karpenter_serviceaccount = "karpenter-controller-sa"
}