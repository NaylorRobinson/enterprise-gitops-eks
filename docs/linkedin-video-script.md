# LinkedIn Demo Video Script
## Enterprise GitOps EKS — UVA Cavaliers Pipeline Demo
**Read this on camera. Target time: under 3 minutes.**

---

## BEFORE YOU HIT RECORD — Open These Tabs
| Tab | What's Open |
|-----|-------------|
| Tab 1 | Live app — ALB URL showing **Version 1.0 Blue** |
| Tab 2 | Jenkins UI — pipeline job ready |
| Tab 3 | ArgoCD UI — showing Synced / Healthy |
| Tab 4 | GitHub repo — ready to show the commit |
| Tab 5 | VS Code — terminal ready to push |

---

## INTRO (0:00 – 0:20)
*Show your screen with the blue app visible*

> "Hey everyone — I want to show you a full GitOps CI/CD pipeline I built on AWS.
> What you're looking at right now is Version 1.0 of my app running live on an
> AWS Application Load Balancer backed by an EKS Kubernetes cluster.
> I'm going to push one line of code to GitHub and show you what happens automatically."

---

## THE CODE PUSH (0:20 – 0:40)
*Switch to VS Code terminal*

> "I'm in VS Code. I've already made my code change — Version 2.0 with
> University of Virginia Cavaliers branding. Watch what happens when I push this."

*Type and run the git push on camera:*
```
git add .
git commit -m "feat: upgrade to V2 UVA Cavaliers theme"
git push origin main
```

> "Code is pushed. Now watch Jenkins."

---

## JENKINS (0:40 – 1:10)
*Switch to Jenkins tab*

> "Jenkins picked it up automatically via GitHub webhook.
> Watch the pipeline stages run in sequence —
> Unit tests... code quality scan... Docker build...
> Trivy security scan... push to ECR... and finally —
> Jenkins updates the GitOps repo with the new image tag."

*Wait for all 7 stages to go green*

> "Seven stages. All green. No manual steps."

📸 **PAUSE HERE — take screenshot of all green stages**

---

## ARGOCD (1:10 – 1:40)
*Switch to ArgoCD tab*

> "Now watch ArgoCD. It detected the image tag change in the GitOps repo
> and it's automatically syncing the cluster."

*Watch status change: OutOfSync → Syncing → Healthy*

> "OutOfSync... Syncing... and Healthy.
> The cluster now matches exactly what's in Git.
> I didn't touch kubectl. I didn't click anything in the AWS console.
> ArgoCD handled the entire deployment."

📸 **PAUSE HERE — take screenshot of ArgoCD Healthy status**

---

## THE REVEAL (1:40 – 2:10)
*Switch to browser tab with the live app*

> "And now — the moment of truth."

*Refresh the browser*

> "Version 2.0. Wahoowa.
> UVA Cavaliers — Navy and Orange — deployed automatically.
> The same pipeline pattern used by companies like Target and Nike."

📸 **PAUSE HERE — take screenshot of V2 UVA app in browser**

---

## OUTRO (2:10 – 2:30)
*Optional: show architecture diagram or GitHub repo*

> "Everything you just saw was built with:
> Terraform for infrastructure — zero manual AWS console clicks.
> Jenkins for CI — tests, security scans, Docker builds.
> ArgoCD for GitOps CD — automatic, self-healing deployments.
> Prometheus and Grafana for observability.
>
> Full repo is on my GitHub — link in the comments.
> Go Hoos."

---

## LINKEDIN CAPTION — Copy This
```
Pushed a code change to GitHub and watched:
→ Jenkins run 7 pipeline stages automatically
→ ArgoCD detect the change and deploy to EKS
→ The live app update in under 2 minutes

No manual kubectl. No console clicks. Just Git.

Infrastructure built entirely with Terraform.
CI with Jenkins. GitOps CD with ArgoCD.
Observability with Prometheus + Grafana.

Full repo: github.com/NaylorRobinson/enterprise-gitops-eks

#DevOps #Kubernetes #GitOps #AWS #EKS #Jenkins #ArgoCD #Terraform #CloudEngineering #UVA #Wahoowa
```
