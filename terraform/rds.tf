# ============================================================
# rds.tf — RDS PostgreSQL Database
# ============================================================
# WHAT THIS FILE DOES:
# Creates a managed PostgreSQL database in your private subnet.
# The password is NOT stored in code — it's generated randomly
# and stored in AWS Secrets Manager automatically.
# ============================================================

# ── DB Subnet Group ──────────────────────────────────────────
# RDS requires a subnet group — tells it which subnets it can use
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ── Random Password for RDS ──────────────────────────────────
# Generates a secure random password — never hardcoded in code
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── Store Password in Secrets Manager ───────────────────────
# Password is stored securely in AWS — Jenkins retrieves it at runtime
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}/db-password"
  description = "RDS PostgreSQL master password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# ── RDS PostgreSQL Instance ──────────────────────────────────
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Automated backups kept for 7 days
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  # Prevents accidental deletion — change to true for production
  deletion_protection = false

  # Skip final snapshot on destroy (useful for dev/demo)
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
