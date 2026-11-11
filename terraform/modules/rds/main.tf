resource "aws_security_group" "db_rahul" {
  name        = "${var.project_name_rahul}-${var.environment_rahul}-rds-sg"
  description = "Allow PostgreSQL only from EKS"
  vpc_id      = var.vpc_id_rahul

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
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
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-rds-sg"
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}

resource "aws_db_subnet_group" "main_rahul" {
  name       = "${var.project_name_rahul}-${var.environment_rahul}-db-subnets"
  subnet_ids = var.private_subnet_ids_rahul

  tags = {
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-db-subnets"
    Environment = var.environment_rahul
  }
}

resource "aws_db_instance" "main_rahul" {
  identifier            = "${var.project_name_rahul}-${var.environment_rahul}-postgres"
  engine                = "postgres"
  engine_version        = "16"
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "taskly"
  username = var.db_username_rahul
  password = var.db_password_rahul
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main_rahul.name
  vpc_security_group_ids = [aws_security_group.db_rahul.id]

  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 7

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-postgres"
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}
