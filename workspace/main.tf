terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "aws" {
  region     = local.region
  access_key = var.access_key
  secret_key = var.secret_key
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = module.eks.cluster_id
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks_auth.token
  }
}

# EKS Fargate Module
################################################################################
module "eks" {
  source = "../modules/eks-fargate"

  cluster_name                   = local.cluster_name
  cluster_version                = local.cluster_version
  karpenter_namespace            = local.k8s_service_karpenter_namespace
  karpenter_serviceaccount       = local.k8s_service_karpenter_serviceaccount
  karpenter_iam_instance_profile = local.karpenter_iam_instance_profile_name

  environment = local.environment
}

## helm release
resource "helm_release" "karpenter" {
  namespace        = local.k8s_service_karpenter_namespace
  create_namespace = true

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = local.karpenter_chart_version

  set {
    name  = "serviceAccount.name"
    value = local.k8s_service_karpenter_serviceaccount
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.karpenter-irsa-role-arn
  }
  ## Karpenter run to Fargate
  set {
    name  = "additionalLabels.eks\\.amazonaws\\.com/fargate-profile"
    value = "karpenter"
  }
  set {
    name  = "controller.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "controller.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = local.karpenter_iam_instance_profile_name
  }

  depends_on = [module.eks]
}