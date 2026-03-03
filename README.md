 Enterprise GitOps CI/CD Pipeline on AWS EKS

> **Push code. Watch it deploy. No manual steps.**

![Jenkins](https://img.shields.io/badge/Jenkins-CI-red) ![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange) ![EKS](https://img.shields.io/badge/AWS-EKS-yellow) ![Terraform](https://img.shields.io/badge/Terraform-IaC-purple) ![Docker](https://img.shields.io/badge/Docker-Container-blue)

---

## What This Project Does

This project demonstrates a production-grade GitOps CI/CD pipeline on AWS. A single `git push` triggers an automated pipeline that builds, tests, scans, and deploys a containerized application to Kubernetes — with zero manual intervention.

**The Demo:** Push code to GitHub → Jenkins builds and scans the Docker image → image is pushed to ECR → ArgoCD detects the change and deploys to EKS → the live app changes from a blue baseline screen (V1) to a UVA Cavaliers Navy/Orange themed page (V2) in under 2 minutes.

---

## Architecture

```
Developer
    │
    │  git push
    ▼
GitHub Repository
    │
    │  webhook trigger
    ▼
Jenkins (EC2 t2.medium)
    │  Stage 1: Checkout
    │  Stage 2: Validate HTML
    │  Stage 3: Docker Build
    │  Stage 4: Trivy Security Scan
    │  Stage 5: Push to ECR
    │  Stage 6: Update deployment.yaml
    ▼
GitHub (deployment.yaml updated with new image tag)
    │
    │  ArgoCD detects Git change
    ▼
ArgoCD (GitOps Controller)
    │
    │  Automated sync
    ▼
AWS EKS (Kubernetes Cluster)
    │
    ▼
Live Application (via AWS ALB)
```

**VPC Layout:** 10.0.0.0/16 across 2 availability zones with public subnets (Jenkins EC2, ALB) and private subnets (EKS nodes, RDS, Redis).

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure as Code — VPC, EKS, EC2, RDS, ECR |
| Jenkins | CI pipeline — build, test, scan, push |
| ArgoCD | GitOps CD — automated deployments from Git |
| AWS EKS | Kubernetes cluster |
| AWS ECR | Docker image registry |
| Docker + nginx:alpine | Application containerization |
| Trivy | Container security scanning |
| Prometheus + Grafana | Cluster monitoring and observability |
| Loki + Promtail | Log aggregation |
| AWS ALB | Application load balancer |
| Ansible | Jenkins EC2 configuration automation |

---

## Project Structure

```
enterprise-gitops-eks/
├── terraform/              # All AWS infrastructure as code
│   ├── main.tf             # Provider config, S3 backend
│   ├── vpc.tf              # VPC, subnets, IGW, NAT gateway
│   ├── eks.tf              # EKS cluster and node group
│   ├── jenkins.tf          # Jenkins EC2 instance
│   ├── security_groups.tf  # Firewall rules
│   ├── ecr.tf              # ECR repositories
│   ├── rds.tf              # PostgreSQL database
│   ├── variables.tf        # Input variables
│   └── outputs.tf          # Output values
├── jenkins/
│   └── Jenkinsfile         # 6-stage CI pipeline
├── argocd/
│   └── argocd-application.yaml  # ArgoCD app definitions
├── k8s/
│   └── base/
│       ├── deployment.yaml # Kubernetes deployment + service
│       └── ingress.yaml    # ALB ingress configuration
├── app/
│   ├── v1/                 # Version 1 — Blue baseline app
│   │   ├── index.html
│   │   └── Dockerfile
│   └── v2/                 # Version 2 — UVA Cavaliers theme
│       ├── index.html
│       └── Dockerfile
├── observability/
│   ├── prometheus/         # Prometheus + Grafana Helm values
│   └── loki/               # Loki + Promtail Helm values
├── ansible/
│   ├── jenkins-setup.yml   # Automated Jenkins EC2 setup
│   └── inventory.ini       # Server inventory
└── docs/
    └── steps.md            # Full build walkthrough
```

---

## How to Run This Project

### Prerequisites

- AWS CLI configured with admin IAM credentials
- Terraform installed
- kubectl installed
- Helm installed
- Docker Desktop running
- Git

### Step 1 — Create S3 bucket for Terraform state

```bash
aws s3 mb s3://enterprise-gitops-eks-tfstate --region us-east-1
```

### Step 2 — Generate SSH key for Jenkins EC2

```bash
# Windows PowerShell
ssh-keygen -t rsa -b 4096 -f jenkins-key.pem
ssh-keygen -y -f jenkins-key.pem | Set-Content jenkins-key.pub -NoNewline
```

### Step 3 — Deploy infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 4 — Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name enterprise-cluster
kubectl get nodes
```

### Step 5 — Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Get ArgoCD password (Windows PowerShell):
```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### Step 6 — Install AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=enterprise-cluster --set serviceAccount.create=true

# Attach required IAM policies to nodes role
aws iam attach-role-policy \
  --role-name enterprise-gitops-eks-eks-nodes-role \
  --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess

aws iam attach-role-policy \
  --role-name enterprise-gitops-eks-eks-nodes-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
```

### Step 7 — Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.persistence.enabled=false \
  --set prometheus.prometheusSpec.storageSpec=null \
  --set alertmanager.alertmanagerSpec.storage=null
```

### Step 8 — Deploy the application

Build and push Docker images to ECR:
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS \
  --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push V1
docker build -t <ecr-registry>/enterprise-gitops-eks/frontend:v1 ./app/v1
docker push <ecr-registry>/enterprise-gitops-eks/frontend:v1
```

Deploy to Kubernetes:
```bash
kubectl create namespace production
kubectl apply -f k8s/base/deployment.yaml -n production
kubectl apply -f k8s/base/ingress.yaml -n production
kubectl apply -f argocd/argocd-application.yaml
```

### Step 9 — Configure Jenkins

1. SSH into Jenkins EC2 via AWS Console → EC2 Instance Connect
2. Run the Ansible playbook (or manually install):
```bash
sudo apt-get install -y fontconfig openjdk-17-jdk
sudo wget -O /opt/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war
sudo java -jar /opt/jenkins.war --httpPort=8080 &
```
3. Open `http://<jenkins-ec2-ip>:8080`
4. Install suggested plugins + AWS Credentials plugin
5. Add credentials:
   - `aws-credentials` — AWS Access Key/Secret (Kind: AWS Credentials)
   - `github-credentials` — GitHub username + Personal Access Token
6. Create Pipeline job pointing to `jenkins/Jenkinsfile`
7. Add GitHub webhook: `http://<jenkins-ip>:8080/github-webhook/`

---

## The CI Pipeline (Jenkinsfile)

| Stage | What It Does |
|-------|-------------|
| 1. Checkout | Pulls latest code from GitHub |
| 2. Validate HTML | Verifies app files exist before building |
| 3. Docker Build | Builds image tagged with git commit hash |
| 4. Trivy Security Scan | Scans for HIGH/CRITICAL CVEs |
| 5. Push to ECR | Authenticates and pushes image to AWS ECR |
| 6. Update GitOps Repo | Updates deployment.yaml — ArgoCD detects and deploys |

---

## Teardown

When done with the demo, destroy all AWS resources to stop billing:

```bash
# Delete EKS node group first (via AWS Console or CLI)
aws eks delete-nodegroup --cluster-name enterprise-cluster \
  --nodegroup-name enterprise-cluster-nodes

# Wait for node group deletion then destroy everything
cd terraform
terraform destroy
```

---

## Troubleshooting

### 1. SSH key encoding error on Windows
**Symptom:** `Character sets beyond ASCII not supported`  
**Cause:** Windows adds BOM encoding to the .pub file  
**Fix:**
```powershell
ssh-keygen -y -f jenkins-key.pem | Set-Content jenkins-key.pub -NoNewline
```

### 2. EKS authentication mode error
**Symptom:** `CreateAccessEntry failed — cluster's authentication mode must be set to API`  
**Cause:** Default EKS auth mode doesn't support API access entries  
**Fix:** Add to `aws_eks_cluster` resource in `eks.tf`:
```hcl
access_config {
  authentication_mode = "API_AND_CONFIG_MAP"
}
```

### 3. Grafana pods stuck in Pending
**Symptom:** `binding volumes: context deadline exceeded`  
**Cause:** EKS has no default storage class for persistent volumes  
**Fix:** Reinstall Prometheus with persistence disabled:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.persistence.enabled=false \
  --set prometheus.prometheusSpec.storageSpec=null
```

### 4. Ingress ADDRESS never populates
**Symptom:** `kubectl get ingress` shows no ADDRESS after 10+ minutes  
**Cause:** AWS Load Balancer Controller not installed, or missing IAM permissions  
**Fix:** Install the controller and attach `ElasticLoadBalancingFullAccess` and `AmazonEC2FullAccess` policies to the EKS nodes IAM role

### 5. Dockerfile not found during Docker build
**Symptom:** `failed to read dockerfile: open Dockerfile: no such file or directory`  
**Cause:** Windows saved the file as `Dockefile` (typo) or `Dockerfile.txt`  
**Fix:**
```powershell
dir app\v1\    # Check actual filename
Rename-Item Dockefile Dockerfile   # Fix typo if present
```

### 6. Node.js v12 conflict blocks v18 install
**Symptom:** `trying to overwrite '/usr/include/node/common.gypi'`  
**Cause:** Ubuntu 22.04 ships Node.js v12 which conflicts with v18 install  
**Fix:**
```bash
sudo apt-get remove -y libnode-dev libnode72
sudo apt-get autoremove -y
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 7. Jenkins webhook causes infinite loop
**Symptom:** Jenkins keeps triggering builds after every build  
**Cause:** Jenkins pushes updated `deployment.yaml` back to GitHub which triggers the webhook again  
**Root cause:** Using same repo for application code and GitOps manifests  
**Fix (temporary):** Disable the webhook in GitHub while Jenkins is running, re-enable only for the demo  
**Fix (production):** Use a separate GitOps repository for Kubernetes manifests so the webhook only triggers on application code changes

### 8. ArgoCD CRD annotation too long
**Symptom:** `The CustomResourceDefinition is invalid: metadata.annotations: Too long`  
**Fix:** Use server-side apply:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
```

### 9. base64 command not found on Windows
**Symptom:** `base64: The term 'base64' is not recognized`  
**Fix:** Use PowerShell native base64 decoding:
```powershell
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | ForEach-Object { 
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) 
}
```

### 10. grep not found on Windows PowerShell
**Symptom:** `grep: The term 'grep' is not recognized`  
**Fix:** Use `Select-String` instead:
```powershell
kubectl get pods -n kube-system | Select-String "aws-load-balancer"
```

---

## Key Learnings

**Why GitOps?** Traditional deployments require someone to manually run `kubectl apply` or click buttons in a console. GitOps uses Git as the single source of truth — when the manifest changes in Git, ArgoCD automatically reconciles the cluster to match. This means deployments are auditable, reversible, and require no manual kubectl access to production.

**Why separate repos in production?** This project uses one repo for both application code and Kubernetes manifests. In production environments these are kept separate so that application changes don't accidentally trigger infrastructure updates and vice versa. A dedicated GitOps repo also allows infrastructure teams to review and approve deployment changes independently.

**Security scanning in the pipeline:** Trivy scans every Docker image for known CVEs before it reaches production. Using `--exit-code 0` allows the pipeline to continue and report findings. In a stricter environment change to `--exit-code 1` to block deployments with CRITICAL vulnerabilities.

---

## Author

**Naylor Robinson**  
GitHub: [@NaylorRobinson](https://github.com/NaylorRobinson)

---

*Built as a DevOps portfolio project demonstrating enterprise-grade GitOps practices on AWS.*
