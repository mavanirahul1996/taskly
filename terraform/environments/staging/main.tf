module "vpc_rahul" {
  source = "../../modules/vpc"

  project_name_rahul         = var.project_taskly_rahul
  environment_rahul          = var.environment_rahul
  vpc_cidr_rahul             = var.vpc_cidr_rahul
  availability_zones_rahul   = var.availability_zones_rahul
  public_subnet_cidrs_rahul  = var.public_subnet_cidrs_rahul
  private_subnet_cidrs_rahul = var.private_subnet_cidrs_rahul
  enable_nat_gateway_rahul   = false
}

module "eks_rahul" {
  source = "../../modules/eks"

  project_name_rahul               = var.project_taskly_rahul
  environment_rahul                = var.environment_rahul
  cluster_name_rahul               = var.cluster_rahul
  cluster_subnet_ids_rahul         = module.vpc_rahul.private_subnet_ids_rahul
  node_subnet_ids_rahul            = module.vpc_rahul.public_subnet_ids_rahul
  cluster_public_access_cidr_rahul = var.cluster_public_access_cidr_rahul
}

module "rds_rahul" {
  source = "../../modules/rds"

  project_name_rahul              = var.project_taskly_rahul
  environment_rahul               = var.environment_rahul
  private_subnet_ids_rahul        = module.vpc_rahul.private_subnet_ids_rahul
  vpc_id_rahul                    = module.vpc_rahul.vpc_id_rahul
  allowed_security_group_id_rahul = module.eks_rahul.cluster_security_group_id_rahul
  db_username_rahul               = var.db_username_rahul
  db_password_rahul               = var.db_password_rahul
}

module "redis_rahul" {
  source = "../../modules/redis"

  project_name_rahul              = var.project_taskly_rahul
  environment_rahul               = var.environment_rahul
  private_subnet_ids_rahul        = module.vpc_rahul.private_subnet_ids_rahul
  vpc_id_rahul                    = module.vpc_rahul.vpc_id_rahul
  allowed_security_group_id_rahul = module.eks_rahul.cluster_security_group_id_rahul
  redis_auth_token_rahul          = var.redis_auth_token_rahul
}
