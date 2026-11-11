variable "project_name_rahul" {
  type = string
}

variable "environment_rahul" {
  type = string
}

variable "private_subnet_ids_rahul" {
  type = list(string)
}

variable "vpc_id_rahul" {
  type = string
}

variable "allowed_security_group_id_rahul" {
  description = "Only EKS security group may access Redis"
  type        = string
}

variable "redis_auth_token_rahul" {
  description = "Redis AUTH token"
  type        = string
  sensitive   = true
}
