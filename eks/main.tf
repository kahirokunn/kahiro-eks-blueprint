locals {
  shared_tags = {
    Terraform   = "true"
    Environment = var.env
    Repo        = var.aws_repo
  }

  min_size = 2
}

terraform {
  required_version = ">= 1.2.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.22.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12.1"
    }
  }
}

data "terraform_remote_state" "iam" {
  backend = "remote"

  config = {
    organization = var.organization
    workspaces = {
      name = var.workspace
    }
  }
}


data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn     = data.terraform_remote_state.iam.outputs.eks-administrator-role.arn
    session_name = "Terraform"
  }
  default_tags {
    tags = local.shared_tags
  }
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

#
# Get the availability zones for our given region
# https://www.terraform.io/docs/providers/aws/d/availability_zones.html
#
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = "${var.cluster_name}-vpc"
  cidr = var.aws_vpc_cidr_block

  azs = data.aws_availability_zones.available.names

  public_subnets  = var.aws_vpc_cidr_public_subnets
  private_subnets = var.aws_vpc_cidr_private_subnets

  enable_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.5.0"

  # EKS CLUSTER
  cluster_version = "1.22"
  cluster_name    = var.cluster_name

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_m5 = {
      node_group_name        = "managed-ondemand"
      instance_types         = ["m5.large"]
      subnet_ids             = module.vpc.private_subnets
      min_size               = local.min_size
      desired_size           = local.min_size
      max_size               = 10
      create_launch_template = true
      launch_template_tags   = local.shared_tags
    }
  }

  map_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      username = "root"
      groups   = ["system:masters"]
    }
  ]

  # https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/9bab01f6214c97c67f66e1e0e32d944cb7b41d9b/examples/node-groups/managed-node-groups/main.tf#L63
  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/kahirokunn/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v0.0.11"

  eks_cluster_id     = module.eks_blueprints.eks_cluster_id
  eks_cluster_domain = var.domain

  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider

  # EKS Addons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  # Kubernetes Add-ons
  argocd_manage_add_ons = true
  enable_argocd         = true
  argocd_helm_config = {
    version = "4.9.14"
  }

  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true
  enable_metrics_server               = true
  # enable_amazon_prometheus = true
  # enable_amazon_eks_adot = true
  # enable_coredns_autoscaler = true
  # enable_crossplane = true
  # enable_ondat = true
  # enable_external_dns = true
  # enable_prometheus = true
  # enable_tetrate_istio = true
  # enable_traefik = true
  # enable_agones = true
  # enable_aws_efs_csi_driver = true
  # enable_aws_fsx_csi_driver = true
  # enable_ingress_nginx = true
  # enable_spark_history_server = true
  # enable_spark_k8s_operator = true
  # enable_aws_for_fluentbit = true
  # enable_aws_cloudwatch_metrics = true
  # enable_fargate_fluentbit = true
  # enable_cert_manager = true
  # enable_argo_rollouts = true
  # enable_aws_node_termination_handler = true
  # enable_karpenter = true
  # enable_keda = true
  # enable_kubernetes_dashboard = true
  # enable_vault = true
  # enable_vpa = true
  # enable_yunikorn = true
  # enable_aws_privateca_issuer = true
  # enable_opentelemetry_operator = true
  # enable_velero = true
  # enable_adot_collector_java = true
  # enable_adot_collector_haproxy = true
  # enable_adot_collector_memcached = true
  # enable_adot_collector_nginx = true
  # enable_secrets_store_csi_driver_provider_aws = true
  # enable_secrets_store_csi_driver = true
  # enable_external_secrets = true
  # enable_grafana = true

  cert_manager_domain_names = var.domain == null ? [] : [var.domain]

  argocd_applications = {
    addons = {
      path               = "chart"
      repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
      add_on_application = true
    }
  }
}
