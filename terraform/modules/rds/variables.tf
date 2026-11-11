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
  description = "Only this EKS security group may access PostgreSQL"
  type        = string
}
variable "db_username_rahul" {
  type = string
}
variable "db_password_rahul" {
  type      = string
  sensitive = true
}
