config {
  module              = true
  deep_check          = true
  force               = false
  disabled_by_default = false
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style   = "flexible"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}
