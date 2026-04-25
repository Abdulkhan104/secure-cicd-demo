# 🚀 Secure CI/CD Pipeline on GCP (GitHub Actions + Cloud Build + GKE)

This project demonstrates an **end-to-end secure CI/CD pipeline on Google Cloud Platform (GCP)** using modern DevSecOps practices.

It integrates:
- GitHub Actions (CI trigger)
- Workload Identity Federation (NO service account keys)
- Cloud Build Private Pool (no internet access)
- Artifact Registry (container storage)
- Private GKE Cluster (secure deployment target)
- Secret Manager (secure secrets handling)
- IAM Least Privilege Access

---

# 🧠 Architecture Overview

Think of it like a secure factory:

- GitHub → Sends code updates
- Cloud Build → Private build room (no internet)
- Artifact Registry → Private container storage
- GKE Cluster → Production deployment environment
- Secret Manager → Secure credential vault
- Workload Identity Federation → Temporary identity cards (no keys)

---

# 🔐 Key Security Features

✔ No service account keys (fully keyless authentication)  
✔ Short-lived credentials via Workload Identity Federation  
✔ Private Cloud Build environment (no public internet)  
✔ IAM least privilege access model  
✔ Secure Kubernetes workloads using Workload Identity  

---

# 📅 Implementation Plan

| Day | Work |
|-----|------|
| Day 1 | GCP setup, APIs enablement, GitHub repo setup |
| Day 2 | Terraform deployment + CI/CD pipeline testing |

---

# 🧰 Prerequisites

Install locally:

- Google Cloud SDK → https://cloud.google.com/sdk/docs/install
- Terraform (v1.6+)
- Git
- GitHub account

Verify:

```bash
gcloud --version
terraform --version
git --version


⚙️ STEP 1: Create GCP Project
gcloud auth login

gcloud projects create secure-cicd-demo-2026 --name="Secure CI/CD Demo"

gcloud config set project YOUR_PROJECT_ID

Enable billing:
https://console.cloud.google.com/billing


🔌 STEP 2: Enable Required APIs
gcloud services enable \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com



  📦 STEP 3: Clone GitHub Repo
git clone https://github.com/YOUR_USERNAME/secure-cicd-demo.git
cd secure-cicd-demo



🏗️ STEP 4: Terraform Infrastructure

Create:

main.tf
variables.tf
terraform.tfvars

This provisions:

✔ VPC Network
✔ Private Cloud Build Pool
✔ Private GKE Cluster
✔ Artifact Registry
✔ IAM Roles
✔ Workload Identity Federation


🚀 STEP 5: Deploy Infrastructure
terraform init
terraform plan
terraform apply -auto-approve

⏳ Wait 10–15 minutes for full deployment.


🔑 STEP 6: Authenticate (No Keys Used)
gcloud auth application-default login


☸️ STEP 7: Configure GKE Workload Identity
gcloud container clusters get-credentials secure-cluster --region us-central1

kubectl create serviceaccount app-ksa

kubectl annotate serviceaccount app-ksa \
iam.gke.io/gcp-service-account=app-sa@PROJECT_ID.iam.gserviceaccount.com


🔁 STEP 8: GitHub Actions Setup

Create file:

.github/workflows/deploy.yml

This workflow:

Authenticates via Workload Identity Federation
Triggers Cloud Build
Deploys to GKE


🔐 STEP 9: GitHub Secrets

Add in GitHub → Settings → Secrets:

Secret	Value
WIF_PROVIDER	Terraform output
GCP_SA_EMAIL	Service account email


🐳 STEP 10: Sample Application
Dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80


index.html
<!DOCTYPE html>
<html>
<head>
  <title>Secure CI/CD</title>
</head>
<body>
  <h1>🚀 Secure CI/CD Pipeline Deployed!</h1>
  <p>No service account keys used. Fully secure pipeline.</p>
</body>
</html>


☁️ STEP 11: Cloud Build Configuration
steps:
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials secure-cluster --region=us-central1
        kubectl apply -f k8s/


🧪 STEP 12: Run Pipeline
git add .
git commit -m "Initial secure CI/CD setup"
git push origin main

Go to:

👉 GitHub → Actions tab

📊 STEP 13: Verify Deployment
kubectl get pods
kubectl get services
kubectl get service my-app

Open:

http://EXTERNAL_IP
🔐 Authentication Flow (Simple)
GitHub sends OIDC identity token
Google verifies repository identity
Temporary credentials are issued
Cloud Build uses temporary access
No permanent credentials exist
🧱 Security Layers
1. Workload Identity Federation
Replaces service account keys
Uses temporary tokens only
2. Private Cloud Build Pool
No internet access
Prevents data exfiltration
3. GKE Workload Identity
Pods get identity automatically
No secrets inside containers
🧹 Cleanup
terraform destroy -auto-approve

(Optional)

gcloud projects delete secure-cicd-demo
💰 Cost Estimate
Service	Cost
GKE	~$0.10/hour
Cloud Build	Pay per use
Artifact Registry	Low storage cost

👉 Total (2 days testing): ~$5–10

🎯 Final Outcome

You successfully built a production-grade secure CI/CD pipeline with:

✔ Zero-trust architecture
✔ Keyless authentication
✔ Private networking
✔ Automated deployments
✔ Enterprise-level security design


