variable "project_name_rahul" {
  type = string
}

variable "environment_rahul" {
  type = string
}

variable "cluster_name_rahul" {
  type = string
}

variable "cluster_version_rahul" {
  type    = string
  default = "1.34"
}

variable "cluster_subnet_ids_rahul" {
  description = "Private subnets for EKS control plane"
  type        = list(string)
}

variable "node_subnet_ids_rahul" {
  description = "Public subnets for EKS worker nodes"
  type        = list(string)
}

variable "cluster_public_access_cidr_rahul" {
  description = "Allowed public IP CIDR for EKS API access"
  type        = string
}

variable "node_instance_types_rahul" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size_rahul" {
  type    = number
  default = 1
}

variable "node_min_size_rahul" {
  type    = number
  default = 1
}

variable "node_max_size_rahul" {
  type    = number
  default = 2
}
