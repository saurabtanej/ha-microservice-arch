terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
    awsutils = {
      source  = "cloudposse/awsutils"
      version = "0.18.1"
    }
  }
  required_version = ">= 1.2"
}
