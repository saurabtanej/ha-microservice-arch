provider "aws" {
  region  = local.aws_region
  profile = local.aws_profile
}

provider "awsutils" {
  region  = "us-east-1"
  profile = local.aws_profile
}
