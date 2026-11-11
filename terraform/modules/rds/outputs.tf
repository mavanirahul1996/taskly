output "db_endpoint_rahul" {
  description = "PostgreSQL database endpoint"
  value       = aws_db_instance.main_rahul.address
}
