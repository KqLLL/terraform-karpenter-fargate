output "cluster_id" {
  value = module.eks.cluster_id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "eks_node_iam_role_name" {
  value = local.karpenter_node_iam_role_name
}

output "eks_fargate_profiles" {
  value = module.eks.fargate_profiles
}

output "karpenter-irsa-role-arn" {
  value = module.iam_assumable_role_cluster_karpenter.iam_role_arn
}

output "karpenter-irsa-role-name" {
  value = module.iam_assumable_role_cluster_karpenter.iam_role_name
}