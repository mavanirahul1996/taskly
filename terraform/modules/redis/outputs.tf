output "redis_endpoint_rahul" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main_rahul.primary_endpoint_address
}

output "redis_port_rahul" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main_rahul.port
}
