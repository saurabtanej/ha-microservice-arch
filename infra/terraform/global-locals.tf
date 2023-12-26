data "aws_caller_identity" "current" {}

data "aws_availability_zones" "zones" {
  state = "available"
}

locals {
  aws_region         = "eu-west-1"
  aws_profile        = "aiq-infra"
  prefix             = "prod"
  environment        = "production"
  account_id         = data.aws_caller_identity.current.account_id
  availability_zones = data.aws_availability_zones.zones.names

  common_tags = {
    Terraform   = "true"
    CreatedBy   = "Terraform"
    Environment = "production"
  }
  vpc_cidr                 = "10.16.0.0/16"
  vpc_public_subnets_cidr  = ["10.16.0.0/22", "10.16.4.0/22", "10.16.8.0/22"]
  vpc_private_subnets_cidr = ["10.16.48.0/22", "10.16.52.0/22", "10.16.56.0/22"]
  vpn_cidr_block           = "10.16.12.0/24"
  eks_cluster_name         = "aiq-${local.environment}"
}
