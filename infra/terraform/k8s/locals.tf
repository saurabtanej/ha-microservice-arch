locals {
  vpc_id             = data.terraform_remote_state.setup.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.setup.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.setup.outputs.public_subnet_ids

  eks_public_access                    = false
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_enabled_log_types            = ["audit", "api", "authenticator"]
  eks_managed_default_disk_size        = 75
  default_node_group_min               = 3
  default_node_group_desired           = 3
  default_node_group_max               = 10
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
  priorityClass = [
    {
      name  = "priorityClassName"
      value = "system-cluster-critical"
    }
  ]
  # Cluster Autoscaler
  enable_cluster_autoscaler    = true
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
      },
      {
        name = "tolerations"
        value = [
          {
            key      = "node"
            operator = "Equal"
            value    = "infrastructure"
            effect   = "NoSchedule"
          }
        ]
      }
    ]
  )
  # Load Balancer Ingress Controller
  enable_lb_ingress_controller = true
  lb_ingress_set = concat(local.priorityClass,
    [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = module.load_balancer_controller_irsa_role.iam_role_arn
        type  = "string"
      },
      {
        name  = "clusterName"
        value = local.eks_cluster_name
        type  = "string"
      },
      {
        name  = "region"
        value = data.aws_region.current.name
        type  = "string"
      },
      {
        name  = "resources.limits.cpu"
        value = "500m"
      },
      {
        name  = "resources.limits.memory"
        value = "1Gi"
      },
      {
        name  = "image.repository"
        value = "602401143452.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/amazon/aws-load-balancer-controller"
      },
      {
        name = "tolerations"
        value = [
          {
            key      = "node"
            operator = "Equal"
            value    = "infrastructure"
            effect   = "NoSchedule"
          }
        ]
      }
    ]
  )
  create_external_alb      = true
  external_acm_certificate = "" # SSL certificate to attach to the external LB in arn format. leaving it blank for the exercise purpose

  # Nginx Ingress Controller
  enable_external_nginx_ingress_controller = true
  external_nginx_ingress_set = concat(local.priorityClass,
    [
      {
        name  = "controller.service.type"
        value = "NodePort"
      },
      {
        name  = "controller.metrics.enabled"
        value = true
      },
      {
        name  = "controller.autoscaling.enabled"
        value = true
      },
      {
        name  = "controller.autoscaling.minReplicas"
        value = "2"
      },
      {
        name  = "controller.autoscaling.maxReplicas"
        value = "10"
      },
      {
        name  = "region"
        value = data.aws_region.current.name
      },
      {
        name  = "controller.resources.limits.cpu"
        value = "500m"
      },
      {
        name  = "controller.resources.limits.memory"
        value = "1Gi"
      },
      {
        name  = "controller.extraArgs.publish-status-address"
        value = "localhost"
      },
      {
        name  = "controller.ingressClassResource.name"
        value = "nginx-external"
      },
      {
        name  = "controller.ingressClassResource.controllerValue"
        value = "k8s.io/nginx-external"
      },
      {
        name  = "controller.ingressClass"
        value = "nginx-external"
      },
      {
        name  = "controller.publishService.enabled"
        value = "false"
      },
      {
        name  = "controller.electionID"
        value = "external-ingress-controller-leader"
      },
      {
        name = "controller.tolerations"
        value = [
          {
            key      = "node"
            operator = "Equal"
            value    = "infrastructure"
            effect   = "NoSchedule"
          }
        ]
      }
    ]
  )

  # Prometheus 
  monitoring_namespace = "monitoring"
  prometheus_set = [
    {
      name = "server.tolerations"
      value = [
        {
          key      = "node"
          operator = "Equal"
          value    = "apps"
          effect   = "NoSchedule"
        }
      ]
    }
  ]
}
