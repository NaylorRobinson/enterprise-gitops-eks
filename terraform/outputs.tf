# ============================================================
# outputs.tf — Output Values
# ============================================================
# WHAT THIS FILE DOES:
# After terraform apply runs, these values are printed to your
# terminal. You'll need them to configure Jenkins, kubectl,
# and ArgoCD. Copy and save these outputs.
# ============================================================

output "vpc_id" {
  description = "VPC ID — needed for manual AWS Console work"
  value       = aws_vpc.main.id
}

output "eks_cluster_name" {
  description = "EKS cluster name — used in kubectl and aws eks commands"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint — Kubernetes control plane URL"
  value       = aws_eks_cluster.main.endpoint
}

output "jenkins_public_ip" {
  description = "Jenkins server public IP — open http://<IP>:8080 in your browser"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI URL — paste this in your browser"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "ecr_registry_url" {
  description = "ECR registry base URL — used in Jenkins to push images"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL connection endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret storing the DB password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl to connect to your cluster"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.eks_cluster_name}"
}
