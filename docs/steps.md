# Enterprise GitOps EKS — Step-by-Step Build Guide
**Author:** Naylor Robinson | **Repo:** github.com/NaylorRobinson/enterprise-gitops-eks

---

## Icon Legend
| Icon | Where to do it |
|------|---------------|
| 🟦 | VS Code Terminal |
| ⬛ | PowerShell (Windows) |
| 🟧 | AWS Console (browser) |
| 🐙 | GitHub |
| 🌐 | Browser (Jenkins UI, ArgoCD UI, Grafana, Live App) |
| 📸 | **TAKE A SCREENSHOT — LinkedIn proof point** |

---

## Prerequisites — Do These First

### ⬛ PowerShell — Verify tools are installed
```powershell
# Check AWS CLI
aws --version

# Check Terraform
terraform --version

# Check kubectl
kubectl version --client

# Check Git
git --version
```
If any are missing, install them before continuing.

### 🟧 AWS Console — Confirm your credentials work
1. Log into AWS Console at https://console.aws.amazon.com
2. Confirm you're in **us-east-1** (top right region selector)
3. Confirm you're logged in as **Naylor.Robinson**

---

## Week 1 — Foundation: VPC + EKS + Jenkins

### Step 1 — Clone the Repo Locally
**🐙 GitHub → 🟦 VS Code**

1. Open GitHub: https://github.com/NaylorRobinson/enterprise-gitops-eks
2. Click the green **Code** button → copy the HTTPS URL
3. Open VS Code Terminal:

```bash
# 🟦 VS Code Terminal
git clone https://github.com/NaylorRobinson/enterprise-gitops-eks.git
cd enterprise-gitops-eks
```

### Step 2 — Create the S3 Bucket for Terraform State
**🟧 AWS Console**

> Terraform needs an S3 bucket to store its state file BEFORE you can run terraform init.
> The state file is how Terraform remembers what it has already built.

1. Go to AWS Console → S3 → **Create bucket**
2. Bucket name: `enterprise-gitops-eks-tfstate`
3. Region: `us-east-1`
4. Block all public access: **ON**
5. Versioning: **Enable** (protects your state file)
6. Click **Create bucket**

📸 **SCREENSHOT** — S3 bucket created with versioning enabled

### Step 3 — Create SSH Key Pair for Jenkins EC2
**🟧 AWS Console**

1. Go to AWS Console → EC2 → **Key Pairs** (left sidebar)
2. Click **Create key pair**
3. Name: `jenkins-key`
4. Key pair type: RSA
5. Private key file format: `.pem`
6. Click **Create key pair** — the `.pem` file downloads automatically
7. Save it somewhere safe (e.g. `C:\Users\YourName\.ssh\jenkins-key.pem`)

Then generate the public key:
```powershell
# ⬛ PowerShell
ssh-keygen -y -f C:\Users\YourName\.ssh\jenkins-key.pem > C:\Users\YourName\.ssh\jenkins-key.pub
```

### Step 4 — Run Terraform
**🟦 VS Code Terminal**

```bash
# Navigate to the terraform folder
cd terraform

# Initialize — downloads AWS provider, connects to S3 backend
terraform init
```
> **What terraform init does:** Downloads the AWS plugin, sets up the S3 backend, prepares the working directory. You only run this once.

```bash
# Preview what will be built — NO changes made yet
terraform plan
```
> **What terraform plan does:** Shows you exactly what AWS resources will be created, modified, or destroyed. Always review this before applying.

📸 **SCREENSHOT** — terraform plan output showing resources to be created

```bash
# Build everything — this takes 10-15 minutes
terraform apply
```
Type `yes` when prompted.

> **What terraform apply does:** Creates all your AWS resources — VPC, subnets, EKS cluster, Jenkins EC2, RDS, ECR repos, security groups. This is the single command that builds your entire infrastructure.

📸 **SCREENSHOT** — terraform apply complete — copy the output values shown at the bottom

**Save the outputs** — you'll need them for the next steps:
- `jenkins_url` — Jenkins UI address
- `eks_cluster_name` — for kubectl
- `ecr_registry_url` — for Jenkinsfile
- `kubeconfig_command` — connect kubectl to EKS

### Step 5 — Connect kubectl to EKS
**🟦 VS Code Terminal**

```bash
# Run the kubeconfig command from terraform outputs
aws eks --region us-east-1 update-kubeconfig --name enterprise-cluster

# Verify connection
kubectl get nodes
```
You should see your 2 worker nodes with status `Ready`.

📸 **SCREENSHOT** — kubectl get nodes showing Ready status

> **Troubleshooting:** If you get "You must be logged in to the server" — this is the known EKS access issue from your previous project. The terraform/eks.tf already creates the access entry for Naylor.Robinson automatically via the `aws_eks_access_entry` resource. If it still fails, go to:
> 🟧 AWS Console → EKS → enterprise-cluster → Access tab → verify Naylor.Robinson has AmazonEKSClusterAdminPolicy

---

## Week 2 — CI Pipeline: Jenkins Setup

### Step 6 — Access Jenkins UI
**🌐 Browser**

1. Open browser and go to: `http://<jenkins_public_ip>:8080`
   (use the `jenkins_url` from terraform outputs)
2. Wait ~2 minutes after terraform apply for Jenkins to finish starting

### Step 7 — Get Jenkins Admin Password
**🟧 AWS Console — EC2 Connect**

1. Go to AWS Console → EC2 → Instances
2. Select your Jenkins instance
3. Click **Connect** → **EC2 Instance Connect** → **Connect**
4. In the browser terminal run:

```bash
sudo cat /root/.jenkins/secrets/initialAdminPassword
```
5. Copy the password

📸 **SCREENSHOT** — Jenkins first login screen in browser

### Step 8 — Configure Jenkins
**🌐 Browser — Jenkins UI**

1. Paste the admin password
2. Click **Install suggested plugins** — wait for install to complete
3. Create your admin user
4. Go to **Manage Jenkins → Credentials → Global → Add Credentials**
5. Add credential 1 — AWS:
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID: your key
   - Secret Access Key: your secret
6. Add credential 2 — GitHub:
   - Kind: Username with password
   - ID: `github-credentials`
   - Username: `NaylorRobinson`
   - Password: your GitHub Personal Access Token
7. Create Pipeline job:
   - New Item → name: `enterprise-frontend-pipeline`
   - Type: Pipeline
   - Pipeline script from SCM → Git
   - Repo URL: `https://github.com/NaylorRobinson/enterprise-gitops-eks.git`
   - Branch: `main`
   - Script Path: `jenkins/Jenkinsfile`
   - Save

📸 **SCREENSHOT** — Jenkins dashboard showing the pipeline job created

### Step 9 — Configure GitHub Webhook
**🐙 GitHub**

1. Go to your repo → **Settings → Webhooks → Add webhook**
2. Payload URL: `http://<jenkins_public_ip>:8080/github-webhook/`
3. Content type: `application/json`
4. Trigger: **Just the push event**
5. Click **Add webhook**

> **What this does:** Every time you push code to GitHub, GitHub sends a notification to Jenkins which automatically triggers the pipeline. This is the automation that makes the demo work.

---

## Week 3 — GitOps: ArgoCD Setup

### Step 10 — Install ArgoCD into EKS
**🟦 VS Code Terminal**

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Save the password — you'll need it for the ArgoCD UI.

```bash
# Port-forward to access ArgoCD UI locally
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

📸 **SCREENSHOT** — ArgoCD UI showing Synced / Healthy status

### Step 11 — Apply ArgoCD App Manifests
**🟦 VS Code Terminal**

```bash
kubectl apply -f argocd/argocd-application.yaml
```
> **What this does:** Tells ArgoCD to watch your GitHub repo and automatically sync changes to the EKS cluster. From this point forward, every git push that updates the image tag will trigger an automatic deployment.

---

## Week 4 — Observability: Prometheus + Grafana + Loki

### Step 12 — Install Prometheus + Grafana
**🟦 VS Code Terminal**

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install the full monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f observability/prometheus/prometheus-values.yaml \
  --namespace monitoring --create-namespace

# Wait for pods to be ready
kubectl get pods -n monitoring --watch
```

```bash
# Port-forward Grafana to your localhost
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

Go to 🌐 http://localhost:3000
- Username: `admin`
- Password: `UVACavaliers2026!`

📸 **SCREENSHOT** — Grafana dashboard showing live pod metrics

### Step 13 — Install Loki
**🟦 VS Code Terminal**

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  -f observability/loki/loki-values.yaml \
  --namespace monitoring
```

---

## Week 5 — The Demo: Blue → UVA Cavaliers

### Step 14 — Deploy V1 (Blue App)
**🟦 VS Code Terminal + 🐙 GitHub**

1. Make sure the frontend deployment is pointing at the V1 app
2. Confirm live app shows blue screen at your ALB URL

📸 **SCREENSHOT** — Browser showing Version 1.0 Blue app with ALB URL visible

### Step 15 — Trigger the Pipeline (THE DEMO)
**🐙 GitHub**

1. Open VS Code → edit `app/v2/index.html` (already created)
2. Push to GitHub:

```bash
# 🟦 VS Code Terminal
git add app/v2/index.html
git commit -m "feat: upgrade to V2 UVA Cavaliers theme"
git push origin main
```

Then watch in order:
- 🌐 **Jenkins** — watch all 7 stages go green
- 🌐 **ArgoCD** — watch status change OutOfSync → Syncing → Healthy
- 🌐 **Browser** — refresh ALB URL — UVA Navy/Orange V2 appears

📸 **SCREENSHOT** — Jenkins all stages green with timestamps
📸 **SCREENSHOT** — ArgoCD showing Healthy status
📸 **SCREENSHOT** — Browser showing Version 2.0 Wahoowa with UVA logo

---

## Teardown — When Demo is Done
**🟦 VS Code Terminal**

```bash
cd terraform
terraform destroy
```
Type `yes` — this deletes all AWS resources and stops billing.

> ⚠️ Don't forget this step — EKS and RDS cost money while running.
