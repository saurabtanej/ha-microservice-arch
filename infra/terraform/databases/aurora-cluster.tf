# RDS Auroracluster with autoscaling enabled, with at least 1 writer and 2 reader across all AZs, and at most 3 readers
module "aiq_rds_cluster" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "9.0.0"

  name           = "aiq-aurora-db-postgres96"
  engine         = "aurora-postgresql"
  engine_version = "14.5"
  instance_class = "db.r6g.large"
  instances = {
    one = {}
    two = {}
  }
  autoscaling_enabled      = true
  autoscaling_min_capacity = 3
  autoscaling_max_capacity = 5

  vpc_id               = local.vpc_id
  db_subnet_group_name = "aiq-db-subnet-group"
  security_group_rules = {
    ingress = {
      cidr_blocks = [local.vpc_cidr]
    }
  }

  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 10

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.common_tags
}
