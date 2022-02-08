locals {
  region                       = "us-east-2"
  instance_types               = ["t3.medium", "t3a.medium"]
  karpenter_node_iam_role_name = "eks-karpenter-worker-node"

  tags = {
    environment = var.environment
  }
}