# ============================================================
# eks.tf — Elastic Kubernetes Service Cluster
# ============================================================
# WHAT THIS FILE DOES:
# Creates your Kubernetes cluster on AWS (EKS).
# EKS has two parts:
# 1. Control Plane — the Kubernetes brain (AWS manages this for you)
# 2. Node Group — the EC2 worker machines where your pods actually run
# Also creates IAM roles — these are permissions that allow EKS
# and your nodes to interact with other AWS services like ECR and ALB.
# ============================================================

# ── IAM Role for EKS Control Plane ──────────────────────────
# Gives the EKS cluster permission to manage AWS resources on your behalf
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# Attach the required AWS-managed policy to the cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ── IAM Role for EKS Worker Nodes ───────────────────────────
# Gives EC2 worker nodes permission to join the cluster and pull from ECR
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Three policies required for worker nodes to function
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

# This allows nodes to pull Docker images from ECR
resource "aws_iam_role_policy_attachment" "eks_ecr_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ── EKS Cluster ──────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true    # Nodes in private subnet can reach control plane
    endpoint_public_access  = true    # You can run kubectl from your laptop
  }
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = var.eks_cluster_name
  }
}

# ── EKS Node Group ───────────────────────────────────────────
# The actual EC2 machines that run your Kubernetes pods
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  # Place nodes in private subnets — they're not directly internet-accessible
  subnet_ids = aws_subnet.private[*].id

  instance_types = [var.eks_node_instance_type]

  scaling_config {
    desired_size = var.eks_desired_nodes
    min_size     = var.eks_min_nodes
    max_size     = var.eks_max_nodes
  }

  # Rolling update — replaces nodes one at a time, keeps cluster available
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read,
  ]

  tags = {
    Name = "${var.project_name}-node-group"
  }
}

# ── EKS Access Entry for Naylor.Robinson ─────────────────────
# Fixes the "You must be logged in to the server" kubectl error
# Grants your IAM user admin access to the EKS cluster
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Naylor.Robinson"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Naylor.Robinson"

  access_scope {
    type = "cluster"
  }
}

# Gets your AWS Account ID dynamically — no need to hardcode it
data "aws_caller_identity" "current" {}
