# Adding `skip` since this terragrunt.hcl is only used to keep the config DRY, it does not define any infrastructure
skip = true

# `SKIP_INIT` can be `true` for testing locally to avoid runnig terraform init for every plan
terraform {
  before_hook "run_init" {
    commands = ["plan", "apply"]
    execute  = get_env("SKIP_INIT", false) ? ["echo", "skip init"] : ["terragrunt", "init"]
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket                = "aiq-backend-state"
    key                   = "${path_relative_to_include()}/terraform.tfstate"
    region                = "eu-west-1"
    encrypt               = true
    dynamodb_table        = "aiq-backend-state"
    profile               = "aiq-infra"
    disable_bucket_update = true
  }
}

generate "terraform_version" {
  path              = ".terraform-version"
  if_exists         = "overwrite"
  contents          = file("./.terraform-version")
  disable_signature = true
}

generate "tflint" {
  path              = ".tflint.hcl"
  if_exists         = "overwrite"
  contents          = file("./.tflint.hcl")
  disable_signature = true
}

generate "global_locals" {
  path              = "global_locals.tf"
  if_exists         = "overwrite"
  contents          = file("./global-locals.tf")
  disable_signature = true
}