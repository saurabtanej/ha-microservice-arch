resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = local.monitoring_namespace
  }
}

resource "helm_release" "kube-prometheus" {
  name       = "kube-prometheus"
  namespace  = local.monitoring_namespace
  version    = "25.8.2"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  dynamic "set" {
    for_each = local.prometheus_set
    content {
      name  = set.value["name"]
      value = set.value["value"]
    }
  }
}
