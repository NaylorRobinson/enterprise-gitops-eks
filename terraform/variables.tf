# ============================================================
# variables.tf — Input Variables
# ============================================================
# WHAT THIS FILE DOES:
# Defines all the variables used across your Terraform files.
# Instead of hardcoding values everywhere, you define them
# once here and reference them with var.variable_name.
# This makes the project reusable and easy to update.
# ============================================================

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for naming all resources"
  type        = string
  default     = "enterprise-gitops-eks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC — the IP range for your entire network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "IP ranges for public subnets (one per availability zone)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "IP ranges for private subnets (one per availability zone)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Two AZs for high availability"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "eks_cluster_name" {
  description = "Name of the EKS Kubernetes cluster"
  type        = string
  default     = "enterprise-cluster"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_nodes" {
  description = "Number of worker nodes to run normally"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "Minimum number of worker nodes (autoscaling floor)"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum number of worker nodes (autoscaling ceiling)"
  type        = number
  default     = 4
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t2.medium"
}

variable "jenkins_ami" {
  description = "Ubuntu Server 22.04 LTS AMI ID for us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "db_instance_class" {
  description = "RDS PostgreSQL instance size"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "enterprisedb"
}

variable "db_username" {
  description = "RDS master username — password stored in Secrets Manager"
  type        = string
  default     = "dbadmin"
}
