module "cluster_autoscaler_irsa_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version     = "5.33.0"
  create_role = local.enable_cluster_autoscaler == true ? true : false

  role_name                        = "${local.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_ids   = [local.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.aiq_eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["${local.cluster_autoscaler_namespace}:cluster-autoscaler"]
    }
  }
  tags = merge(local.common_tags, { Name = "${local.eks_cluster_name}-autoscaler-role" })

  depends_on = [
    module.aiq_eks_cluster
  ]

}

resource "helm_release" "cluster_autoscaler" {
  count = local.enable_cluster_autoscaler ? 1 : 0
  chart = "cluster-autoscaler"

  create_namespace = true
  namespace        = local.cluster_autoscaler_namespace
  name             = "cluster-autoscaler"
  version          = "9.34.1"
  repository       = "https://kubernetes.github.io/autoscaler"

  values = [
    data.autoscaler_utils_deep_merge_yaml.values[0].output
  ]

  dynamic "set" {
    for_each = local.cluster_autoscaler_set
    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
  depends_on = [
    module.cluster_autoscaler_irsa_role
  ]
}
