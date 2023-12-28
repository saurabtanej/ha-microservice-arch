# IAM role required for AWS Load Balancer Controller
module "load_balancer_controller_irsa_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version     = "5.33.0"
  create_role = local.enable_lb_ingress_controller == true ? true : false

  role_name = "${local.eks_cluster_name}-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.aiq_eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:load-balancer-controller-aws-load-balancer-controller"]
    }
  }
  depends_on = [
    module.aiq_eks_cluster
  ]
}

# AWS Load Balancer Controller
resource "helm_release" "aws_loadbalancer_controller" {
  count      = local.enable_lb_ingress_controller == true ? 1 : 0
  namespace  = "kube-system"
  name       = "load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.2"

  dynamic "set" {
    for_each = local.lb_ingress_set
    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
}

# Ingress Resource with LB controller to create an ALB with nginx controller service as a backend
resource "kubectl_manifest" "ingress_external_alb" {
  count = (local.enable_lb_ingress_controller == true) && (local.create_external_alb == true) ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/ingress-alb.tmpl", {
    acm_certificate     = local.external_acm_certificate
    alb_schema          = "internet-facing"
    subnet_lists        = join(",", local.public_subnet_ids)
    backend_service     = "external-ingress-nginx-controller"
    ingress_name        = "alb-ingress-connect-nginx-external"
    namespace           = "kube-system"
    alb_security_groups = join(",", aws_security_group.eks_external_alb.id)
  })

  depends_on = [
    helm_release.aws_loadbalancer_controller
  ]
}

# Nginx Ingress Controller to manager Applications route deployed as NodePort
resource "helm_release" "external_nginx_ingress_controller" {
  count = local.enable_external_nginx_ingress_controller == true ? 1 : 0

  namespace  = "kube-system"
  name       = "external-ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.9.0"

  dynamic "set" {
    for_each = local.external_nginx_ingress_set
    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
  depends_on = [
    helm_release.aws_loadbalancer_controller,
    kubectl_manifest.ingress_external_alb
  ]
}
