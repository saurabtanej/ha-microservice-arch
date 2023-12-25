# Assignig EIPs to Nat Gateways
resource "aws_eip" "nat" {
  count = 3

  domain   = "vpc"
}

module "aiq_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name = "aiq-vpc"
  cidr = local.vpc_cidr


  azs             = local.availability_zones
  private_subnets = local.vpc_private_subnets_cidr
  public_subnets  = local.vpc_public_subnets_cidr

  enable_nat_gateway   = true
  single_nat_gateway   = false
  reuse_nat_ips        = true
  external_nat_ip_ids  = aws_eip.nat.*.id
  enable_dns_hostnames = true

  tags = local.common_tags
  private_subnet_tags = local.eks_cluster_name != "" ? {
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"                 = "1"
  } : {}
}