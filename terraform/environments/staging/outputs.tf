output "vpc_id_rahul" {
  description = "Taskly staging VPC ID"
  value       = module.vpc_rahul.vpc_id_rahul
}

output "public_subnet_ids_rahul" {
  description = "Public subnet IDs"
  value       = module.vpc_rahul.public_subnet_ids_rahul
}

output "private_subnet_ids_rahul" {
  description = "Private subnet IDs"
  value       = module.vpc_rahul.private_subnet_ids_rahul
}

output "nat_gateway_id_rahul" {
  description = "Staging NAT Gateway ID"
  value       = module.vpc_rahul.nat_gateway_id_rahul
}

output "eks_cluster_name_rahul" {
  description = "EKS cluster name"
  value       = module.eks_rahul.cluster_name_rahul
}

output "eks_cluster_endpoint_rahul" {
  description = "EKS API endpoint"
  value       = module.eks_rahul.cluster_endpoint_rahul
}

output "eks_node_group_name_rahul" {
  description = "EKS managed worker node group"
  value       = module.eks_rahul.node_group_name_rahul
}

output "rds_endpoint_rahul" {
  description = "PostgreSQL endpoint"
  value       = module.rds_rahul.db_endpoint_rahul
}

output "redis_endpoint_rahul" {
  description = "Redis endpoint"
  value       = module.redis_rahul.redis_endpoint_rahul
}

output "redis_port_rahul" {
  description = "Redis port"
  value       = module.redis_rahul.redis_port_rahul
}
