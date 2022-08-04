module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.2.0"

  role_name                          = "karpenter-controller-${var.cluster_name}"
  attach_karpenter_controller_policy = true
  karpenter_controller_cluster_id    = module.eks.cluster_id
  karpenter_controller_node_iam_role_arns = [
    module.eks.eks_managed_node_groups["karpenter"].iam_role_arn
  ]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}
