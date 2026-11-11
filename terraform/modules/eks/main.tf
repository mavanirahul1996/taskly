resource "aws_iam_role" "cluster_rahul" {
  name = "${var.project_name_rahul}-${var.environment_rahul}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = var.project_name_rahul
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy_rahul" {
  role       = aws_iam_role.cluster_rahul.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main_rahul" {
  name     = var.cluster_name_rahul
  role_arn = aws_iam_role.cluster_rahul.arn
  version  = var.cluster_version_rahul

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids_rahul
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.cluster_public_access_cidr_rahul]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy_rahul
  ]

  tags = {
    Project     = var.project_name_rahul
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}

# Worker node IAM role
resource "aws_iam_role" "node_rahul" {
  name = "${var.project_name_rahul}-${var.environment_rahul}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = var.project_name_rahul
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}

resource "aws_iam_role_policy_attachment" "node_worker_rahul" {
  role       = aws_iam_role.node_rahul.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_rahul" {
  role       = aws_iam_role.node_rahul.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_rahul" {
  role       = aws_iam_role.node_rahul.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Managed EC2 worker nodes
resource "aws_eks_node_group" "main_rahul" {
  cluster_name    = aws_eks_cluster.main_rahul.name
  node_group_name = "${var.project_name_rahul}-${var.environment_rahul}-nodes"
  node_role_arn   = aws_iam_role.node_rahul.arn
  subnet_ids      = var.node_subnet_ids_rahul

  instance_types = var.node_instance_types_rahul
  capacity_type  = "SPOT"

  scaling_config {
    desired_size = var.node_desired_size_rahul
    min_size     = var.node_min_size_rahul
    max_size     = var.node_max_size_rahul
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    environment = var.environment_rahul
    project     = var.project_name_rahul
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_rahul,
    aws_iam_role_policy_attachment.node_cni_rahul,
    aws_iam_role_policy_attachment.node_ecr_rahul
  ]

  tags = {
    Project     = var.project_name_rahul
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}
