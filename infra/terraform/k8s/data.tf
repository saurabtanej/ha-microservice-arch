data "autoscaler_utils_deep_merge_yaml" "values" {
  count = local.enable_cluster_autoscaler ? 1 : 0
  input = compact([
    local.cluster_autoscaler_values,
    ""
  ])
}
