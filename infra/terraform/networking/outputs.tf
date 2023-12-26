output "vpc_id" {
  value = module.aiq_vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.aiq_vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.aiq_vpc.private_subnets
}

output "private_route_table_ids" {
  value = module.aiq_vpc.private_route_table_ids
}

output "public_route_table_ids" {
  value = module.aiq_vpc.public_route_table_ids
}
