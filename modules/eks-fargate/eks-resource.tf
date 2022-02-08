data "aws_caller_identity" "current" {}

################################################################################
# EKS Module
################################################################################
module "eks" {
  source  = "registry.terraform.io/terraform-aws-modules/eks/aws"
  version = ">18"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  ## EKS addons
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.iam_assumable_role_cni.iam_role_arn
    }
  }

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    },
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    create_security_group          = true
    security_group_name            = "eks-managed-node-group-complete"
    security_group_use_name_prefix = false
    security_group_description     = "EKS managed node group complete security group"


    update_launch_template_default_version = true
    instance_types                         = local.instance_types
  }

  eks_managed_node_groups = {
    karpenter = {
      name = "karpenter-eks-mng"

      create_launch_template = true
      use_name_prefix        = false

      #iam_role_arn = aws_iam_role.worker_role.arn
      create_iam_role = true

      subnet_ids = module.vpc.private_subnets

      min_size     = 0
      max_size     = 3
      desired_size = 0
    }
  }

  fargate_profiles = {
    coredns = {
      name = "coredns"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app : "kube-dns"
          }
        }
      ]

      subnet_ids = module.vpc.private_subnets

      tags = {
        Owner = "coredns"
      }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }

    karpenter = {
      name = "karpenter"

      selectors = [
        {
          namespace = "karpenter"
          labels = {
            WorkerType = "fargate"
            Role       = "karpenter"
          }
        }
      ]

      # Using specific subnets instead of the subnets supplied for the cluster itself
      #subnet_ids = [module.vpc.private_subnets[1]]
      subnet_ids = module.vpc.private_subnets

      tags = {
        Owner = "karpenter"
      }
    }
  }

  tags = {
    Cluster = var.cluster_name
  }
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "registry.terraform.io/terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.cluster_name
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "karpenter.sh/discovery"                    = var.cluster_name
    "kubernetes.io/role/internal-elb"           = 1
  }

  tags = local.tags
}


###Karpenter worker node role ########################
data "aws_iam_policy" "ssm_managed_instance" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_ssm_policy" {
  role       = module.eks.eks_managed_node_groups["karpenter"].iam_role_name
  policy_arn = data.aws_iam_policy.ssm_managed_instance.arn
}

resource "aws_iam_instance_profile" "karpenter" {
  name = var.karpenter_iam_instance_profile
  #role = aws_iam_role.worker_role.name
  role = module.eks.eks_managed_node_groups["karpenter"].iam_role_name
}
