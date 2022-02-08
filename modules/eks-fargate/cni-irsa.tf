####### cni_irsa
module "iam_assumable_role_cni" {
  source                        = "registry.terraform.io/terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.10.1"
  create_role                   = true
  role_name                     = "cni-controller-${var.cluster_name}"
  role_policy_arns              = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
  provider_url                  = module.eks.cluster_oidc_issuer_url
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-node"]
}