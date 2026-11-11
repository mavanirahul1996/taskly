variable "project_name_rahul" {
  description = "Project name"
  type        = string
}

variable "environment_rahul" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr_rahul" {
  description = "VPC network IP range"
  type        = string
}

variable "availability_zones_rahul" {
  description = "AWS availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs_rahul" {
  description = "Public subnet IP ranges"
  type        = list(string)
}

variable "private_subnet_cidrs_rahul" {
  description = "Private subnet IP ranges"
  type        = list(string)
}

variable "enable_nat_gateway_rahul" {
  description = "Enable one shared NAT Gateway for staging"
  type        = bool
  default     = true
}
