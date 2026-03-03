# ============================================================
# jenkins.tf — Jenkins EC2 Instance
# ============================================================
# WHAT THIS FILE DOES:
# Launches the EC2 server that runs Jenkins.
# Uses a user_data script (bash that runs on first boot) to:
# - Update the OS
# - Install Java 17 (Jenkins requires it)
# - Download and start Jenkins using the WAR file method
#   (apt install is broken on Ubuntu 22.04 — WAR file is the fix)
# ============================================================

# ── Key Pair ─────────────────────────────────────────────────
# You need an SSH key pair to connect to the EC2 instance
# Create one in AWS Console → EC2 → Key Pairs, name it "jenkins-key"
# Download the .pem file and keep it safe
resource "aws_key_pair" "jenkins" {
  key_name   = "jenkins-key"
  public_key = file("C:/Users/kwako/.ssh/jenkins-key.pub")   # Path to your public key on Windows

  lifecycle {
    ignore_changes = [key_name]  # Don't try to update the key if it changes local
  }
}

# ── Jenkins EC2 Instance ─────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                    = var.jenkins_ami           # Ubuntu Server 22.04 LTS
  instance_type          = var.jenkins_instance_type # t2.medium
  key_name               = aws_key_pair.jenkins.key_name
  subnet_id              = aws_subnet.public[0].id   # Public subnet — needs internet access
  vpc_security_group_ids = [aws_security_group.jenkins.id]

  # 30GB storage — Jenkins needs space for build artifacts
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # This script runs automatically when EC2 first boots
  # It installs Java and starts Jenkins using the WAR file method
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update OS packages
    apt-get update -y
    apt-get upgrade -y

    # Install Java 17 — Jenkins requires it
    apt-get install -y fontconfig openjdk-17-jdk

    # Install AWS CLI — needed for Jenkins to push to ECR
    apt-get install -y unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./install
    rm -rf awscliv2.zip aws

    # Install Docker — Jenkins uses it to build images
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

    # Install kubectl — Jenkins uses it to interact with EKS
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Download Jenkins WAR file — this is the working install method
    # apt install is broken on Ubuntu 22.04 due to GPG key issue
    mkdir -p /opt/jenkins
    wget -O /opt/jenkins/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war

    # Create a systemd service so Jenkins starts automatically on reboot
    cat > /etc/systemd/system/jenkins.service <<'SERVICE'
    [Unit]
    Description=Jenkins Automation Server
    After=network.target

    [Service]
    Type=simple
    User=root
    ExecStart=/usr/bin/java -jar /opt/jenkins/jenkins.war --httpPort=8080
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins

    echo "Jenkins installation complete. Access at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
  EOF

  tags = {
    Name = "${var.project_name}-jenkins"
  }
}

# ── Elastic IP for Jenkins ───────────────────────────────────
# Gives Jenkins a static public IP that doesn't change on reboot
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-jenkins-eip"
  }
}
