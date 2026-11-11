output "cluster_name_rahul" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main_rahul.name
}

output "cluster_endpoint_rahul" {
  description = "EKS API endpoint"
  value       = aws_eks_cluster.main_rahul.endpoint
}

output "node_group_name_rahul" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.main_rahul.node_group_name
}

output "node_role_arn_rahul" {
  description = "Worker node IAM role ARN"
  value       = aws_iam_role.node_rahul.arn
}

output "cluster_security_group_id_rahul" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.main_rahul.vpc_config[0].cluster_security_group_id
}
