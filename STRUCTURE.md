# enterprise-gitops-eks
## Project Structure

```
enterprise-gitops-eks/
│
├── terraform/                        # All AWS infrastructure (build this first)
│   ├── main.tf                       # Provider config + S3 backend
│   ├── variables.tf                  # All input variables
│   ├── vpc.tf                        # VPC, subnets, IGW, NAT, route tables
│   ├── security_groups.tf            # Firewall rules for all resources
│   ├── eks.tf                        # EKS cluster + node group + IAM roles
│   ├── jenkins.tf                    # Jenkins EC2 + Elastic IP
│   ├── rds.tf                        # PostgreSQL database
│   ├── ecr.tf                        # Docker image repositories
│   └── outputs.tf                    # Printed values after terraform apply
│
├── jenkins/
│   └── Jenkinsfile                   # CI pipeline — 7 stages
│
├── argocd/
│   └── argocd-application.yaml       # ArgoCD app definitions (dev/staging/prod)
│
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml           # Kubernetes Deployment + Service
│   │   └── ingress.yaml              # ALB Ingress (public URL)
│   └── overlays/
│       ├── dev/                      # Dev environment overrides
│       ├── staging/                  # Staging environment overrides
│       └── production/               # Production environment overrides
│
├── app/
│   ├── v1/
│   │   └── index.html                # Version 1.0 — Blue baseline app
│   └── v2/
│       └── index.html                # Version 2.0 — UVA Cavaliers theme
│
├── observability/
│   ├── prometheus/
│   │   └── prometheus-values.yaml    # Prometheus + Grafana + Alertmanager config
│   └── loki/
│       └── loki-values.yaml          # Loki log aggregation config
│
└── docs/
    ├── steps.md                      # Full build guide with screenshot callouts
    ├── linkedin-video-script.md      # Camera read-along for demo recording
    └── README.md                     # SOART method — written after project complete
```

## Build Order
1. `terraform/` — build all infrastructure first
2. `jenkins/` — configure CI pipeline
3. `argocd/` + `k8s/` — set up GitOps deployment
4. `app/` — deploy V1, then trigger pipeline to deploy V2
5. `observability/` — add monitoring and logging
