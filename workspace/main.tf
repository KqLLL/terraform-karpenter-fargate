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

data "aws_eks_cluster" "eks_cluster" {
  name = local.cluster_name

  depends_on = [module.eks.eks_fargate_profiles]
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = module.eks.cluster_id

  depends_on = [module.eks.eks_fargate_profiles]
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks_auth.token
  }
}

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = data.aws_eks_cluster.eks_cluster.id
      cluster = {
        certificate-authority-data = data.aws_eks_cluster.eks_cluster.certificate_authority[0].data
        server                     = data.aws_eks_cluster.eks_cluster.endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = data.aws_eks_cluster.eks_cluster.id
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.eks_auth.token
      }
    }]
  })
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

resource "null_resource" "patch_coredns" {
  triggers = {
    kubeconfig = base64encode(local.kubeconfig)
    cmd_patch = "kubectl patch deployment coredns -n kube-system --type json -p='[{\"op\": \"remove\", \"path\": \"/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type\"}]' --kubeconfig <(echo $KUBECONFIG | base64 --decode) | true"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
    command = self.triggers.cmd_patch
  }

  depends_on = [module.eks.eks_fargate_profiles]
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