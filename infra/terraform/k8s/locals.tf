locals {
  vpc_id             = data.terraform_remote_state.setup.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.setup.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.setup.outputs.public_subnet_ids

  eks_public_access                    = false
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_enabled_log_types            = ["audit", "api", "authenticator"]
  eks_managed_default_disk_size = 75
  default_node_group_min        = 3
  default_node_group_desired    = 3
  default_node_group_max        = 10
  additional_policies = {
    ecr_policy              = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    cloydwatch_agent_policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ebs_csi_driver_policy   = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    ssm_policy              = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
  }

  # Cluster ADD-ONS
  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
  }
  # Cluster Autoscaler
  enable_cluster_autoscaler = true
  cluster_autoscaler_namespace = "kube-system"
  cluster_autoscaler_values = yamlencode({
    "awsRegion" : data.aws_region.current.name,
    "autoDiscovery" : {
      "clusterName" : local.eks_cluster_name
    },
    "rbac" : {
      "create" : "true",
      "serviceAccount" : {
        "create" : "true",
        "name" : "cluster-autoscaler"
        "annotations" : {
          "eks.amazonaws.com/role-arn" : module.cluster_autoscaler_irsa_role.iam_role_arn
        }
      }
    }
  })
  cluster_autoscaler_set = concat(local.priorityClass,
    [
      {
        name  = "resources.limits.memory"
        value = "500Mi"
        type  = "string"
      }
    ]
  )
  priorityClass = [
    {
      name  = "priorityClassName"
      value = "system-cluster-critical"
    }
  ]

}
