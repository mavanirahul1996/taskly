output "vpc_id_rahul" {
  description = "ID of the Taskly VPC"
  value       = aws_vpc.main_rahul.id
}

output "public_subnet_ids_rahul" {
  description = "IDs of public subnets"
  value       = aws_subnet.public_rahul[*].id
}

output "private_subnet_ids_rahul" {
  description = "IDs of private subnets"
  value       = aws_subnet.private_rahul[*].id
}

output "nat_gateway_id_rahul" {
  description = "Staging NAT Gateway ID"
  value       = try(aws_nat_gateway.main_rahul[0].id, null)
}
