# ============================================================
# main.tf — Enterprise GitOps EKS Project
# Author: Naylor Robinson
# Repo: github.com/NaylorRobinson/enterprise-gitops-eks
# Region: us-east-1
# ============================================================
# WHAT THIS FILE DOES:
# This is the entry point for Terraform. It tells Terraform
# which cloud provider to use (AWS), which region to deploy
# in, and where to store the state file (S3 backend).
# The state file is how Terraform remembers what it built.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }

  # Remote state stored in S3 so your team (or future you) can access it
  backend "s3" {
    bucket = "enterprise-gitops-eks-tfstate"
    key    = "terraform/state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "enterprise-gitops-eks"
      Owner       = "Naylor.Robinson"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}
