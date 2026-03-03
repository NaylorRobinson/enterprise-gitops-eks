# ============================================================
# vpc.tf — Virtual Private Cloud + Networking
# ============================================================
# WHAT THIS FILE DOES:
# Builds your entire AWS network from scratch:
# - VPC: your isolated private network in AWS
# - Public subnets: where Jenkins EC2 and the Load Balancer live
# - Private subnets: where EKS, RDS, and Redis live (no direct internet)
# - Internet Gateway: allows public subnet resources to reach the internet
# - NAT Gateway: allows private subnet resources to reach the internet
#   (for downloading packages) without being exposed to it
# - Route tables: traffic rules — tells AWS where to send packets
# ============================================================

# ── VPC ─────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # Allows EC2 instances to get DNS names
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ── Internet Gateway ─────────────────────────────────────────
# Attaches to the VPC and allows traffic to/from the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ── Public Subnets ───────────────────────────────────────────
# One subnet per availability zone for high availability
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Resources launched here automatically get a public IP
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                      = "1"   # Tells EKS this subnet is for load balancers
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# ── Private Subnets ──────────────────────────────────────────
# EKS nodes, RDS, and Redis live here — no direct internet access
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                          = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# ── Elastic IP for NAT Gateway ───────────────────────────────
# NAT Gateway needs a static public IP address
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# ── NAT Gateway ──────────────────────────────────────────────
# Lives in the public subnet, gives private subnet outbound internet access
# Private subnet resources can download packages but can't be reached from internet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id   # Always put NAT in a public subnet

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat"
  }
}

# ── Public Route Table ───────────────────────────────────────
# Rule: all internet traffic (0.0.0.0/0) goes through the Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate both public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table ──────────────────────────────────────
# Rule: outbound internet traffic goes through NAT Gateway (not IGW)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate both private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
