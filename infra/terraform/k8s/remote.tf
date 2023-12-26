data "terraform_remote_state" "setup" {
  backend = "s3"
  config = {
    bucket  = "aiq-backend-state"
    key     = "setup/terraform.tfstate"
    region  = local.aws_region
    profile = local.aws_profile
  }
}
