module "aiq_eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name                         = local.eks_cluster_name
  cluster_version                      = 1.27
  cluster_endpoint_private_access      = local.vpc_id
  cluster_endpoint_public_access       = local.eks_public_access
  cluster_endpoint_public_access_cidrs = local.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types            = local.cluster_enabled_log_types

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
    ingress_https = {
      description = "Access from default vpc and self"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [local.vpc_cidr]
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  iam_role_additional_policies = local.additional_policies

  cluster_addons = local.cluster_addons

  manage_aws_auth_configmap = true

  # Below can be maaged to provide access to eks cluster, below is an example to provide admin access, but in prod it should be controlled access
  #   aws_auth_roles                   = {
  #         rolearn  = "add_devops_or_admin_role_to_provide_devops_full_access_to_eks_cluster_in_arn_format"
  #         username = "admins"
  #         groups   = ["system:masters"]
  #       }
  #   aws_auth_users                   =  {
  #         rolearn  = "add_iam_user_to_provide_full_access_to_eks_cluster_in_arn_format"
  #         username = "admin"
  #         groups   = ["system:masters"]
  #       }

  enable_irsa = true

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type                     = "BOTTLEROCKET_x86_64"
    platform                     = "bottlerocket"
    disk_size                    = local.eks_managed_default_disk_size
    instance_types               = ["c5.xlarge", "c5d.xlarge", "r5.xlarge", "c5a.xlarge"]
    min_size                     = local.default_node_group_min
    max_size                     = local.default_node_group_max
    desired_size                 = local.default_node_group_desired
    iam_role_additional_policies = local.additional_policies
    iam_role_attach_cni_policy   = true
  }

  eks_managed_node_groups = {

    infrastructure = {
      use_custom_launch_template = false

      # Remote access cannot be specified with a launch template
      remote_access = {
        ec2_ssh_key               = "devops"
        source_security_group_ids = [aws_security_group.eks_ssh_access.id] # this is required or module will create a SG automatically with ssh open to 0.0.0.0/0 when remote_access is enabled
      }

      iam_role_name = "infrastructure-node"

      tags = merge(local.common_tags, {
        Name = "${local.eks_cluster_name}-infrastructure"
      })

      labels = {
        node = "infrastructure"
      }

      # Adding taits to make sure infra resources like cluster autoscaler, ingress controllers are deployed in these nodes only and none other
      taints = [{
        key    = "node"
        value  = "infrastructure"
        effect = "NO_SCHEDULE"
      }]
    }

    apps = {
      use_custom_launch_template = false

      # Remote access cannot be specified with a launch template
      remote_access = {
        ec2_ssh_key               = "devops"
        source_security_group_ids = [aws_security_group.eks_ssh_access.id] # this is required or module will create a SG automatically with ssh open to 0.0.0.0/0 when remote_access is enabled
      }

      iam_role_name  = "app-node"
      instance_types = ["c5.xlarge", "c5a.xlarge", "m5.xlarge", "m5a.xlarge"]

      labels = {
        node = "apps"
      }

      # Adding taits to make sure infra resources like cluster autoscaler, ingress controllers are deployed in these nodes only and none other
      taints = [{
        key    = "node"
        value  = "apps"
        effect = "NO_SCHEDULE"
      }]

      tags = merge(local.common_tags, {
        Name = "${local.eks_cluster_name}-apps"
      })
    }
  }

  tags = merge(local.common_tags, { Name = local.eks_cluster_name })
}

# this is required or module will create a SG automatically with ssh open to 0.0.0.0/0 when remote_access is enabled
resource "aws_security_group" "eks_ssh_access" {
  name_prefix = "${local.eks_cluster_name}-ssh-access"
  description = "Allow remote SSH access from withi the vpc"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.eks_cluster_name}-ssh-access" })
}

# ALB SG 
resource "aws_security_group" "eks_external_alb" {
  name_prefix = "${local.eks_cluster_name}-external-alb
  description = "Allow Access to Public Apps from Internet"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTPS Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.eks_cluster_name}-ssh-access" })
}
