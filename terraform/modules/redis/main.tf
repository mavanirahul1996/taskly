resource "aws_security_group" "redis_rahul" {
  name        = "${var.project_name_rahul}-${var.environment_rahul}-redis-sg"
  description = "Allow Redis only from EKS"
  vpc_id      = var.vpc_id_rahul

  ingress {
    description     = "Redis from EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id_rahul]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-redis-sg"
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}

resource "aws_elasticache_subnet_group" "main_rahul" {
  name       = "${var.project_name_rahul}-${var.environment_rahul}-redis-subnets"
  subnet_ids = var.private_subnet_ids_rahul

  tags = {
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-redis-subnets"
    Environment = var.environment_rahul
  }
}

resource "aws_elasticache_replication_group" "main_rahul" {
  replication_group_id = "${var.project_name_rahul}-${var.environment_rahul}-redis"
  description          = "Taskly ${var.environment_rahul} Redis"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.t4g.micro"
  num_cache_clusters   = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main_rahul.name
  security_group_ids = [aws_security_group.redis_rahul.id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = var.redis_auth_token_rahul

  automatic_failover_enabled = false
  multi_az_enabled           = false
  apply_immediately          = false

  tags = {
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-redis"
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}
