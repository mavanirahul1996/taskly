variable "project_taskly_rahul" {
  description = "Name of the project"
  type        = string
  default     = "taskly"
}

variable "environment_rahul" {
  description = "Deployment environment"
  type        = string
  default     = "staging"
}

variable "cluster_rahul" {
  description = "EKS cluster name"
  type        = string
  default     = "taskly-staging"
}

variable "vpc_cidr_rahul" {
  description = "Network IP range"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones_rahul" {
  description = "AWS availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnet_cidrs_rahul" {
  description = "Public subnet IP ranges"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs_rahul" {
  description = "Private subnet IP ranges"
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "db_username_rahul" {
  description = "Taskly PostgreSQL username"
  type        = string
  default     = "tasklyadmin"
}

variable "db_password_rahul" {
  description = "Taskly PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "cluster_public_access_cidr_rahul" {
  description = "Allowed public IP for EKS API access"
  type        = string
  default     = "93.235.31.239/32"
}

variable "redis_auth_token_rahul" {
  description = "Redis AUTH token (16-128 alphanumeric characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.redis_auth_token_rahul) >= 16 && length(var.redis_auth_token_rahul) <= 128 && can(regex("^[A-Za-z0-9]+$", var.redis_auth_token_rahul))
    error_message = "Redis AUTH token must contain 16-128 alphanumeric characters."
  }
}
