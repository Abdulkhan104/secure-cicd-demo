# Secure CI/CD Pipeline on GCP

A production-grade, zero-trust CI/CD pipeline on Google Cloud Platform using **Workload Identity Federation**, **private Cloud Build**, and **GKE**.

---

## Architecture

```
     YOU PUSH CODE             AUTHENTICATION                BUILD
           │                         │                         │
           ▼                         ▼                         ▼
  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
  │    GitHub       │     │    Workload     │     │   Cloud Build   │
  │    Repository   │     │    Identity     │     │  Private Pool   │
  │                 │     │    Federation   │     │                 │
  │   main branch   │     │                 │     │   NO INTERNET   │
  └────────┬────────┘     └────────┬────────┘     └────────┬────────┘
           │                       │                        │
           │ 1. Push code          │ 2. Passwordless        │ 3. Build container
           │                       │    identity proof      │    in isolation
           ▼                       ▼                        ▼

      STORAGE                 DEPLOYMENT                  SECRETS
           │                       │                        │
           ▼                       ▼                        ▼
  ┌─────────────────┐     ┌─────────────────┐     ┌────────────────┐
  │    Artifact     │     │   GKE Cluster   │     │    Secret      │
  │    Registry     │     │   (Private)     │     │    Manager     │
  │                 │     │                 │     │                │
  │  Docker images  │     │  3 worker nodes │     │  API keys      │
  │  stored safely  │     │                 │     │  DB creds      │
  └────────┬────────┘     └────────┬────────┘     └───────┬────────┘
           │                       │                       │
           │ 4. Image pushed       │ 5. Deployed to        │ 6. App reads
           │    to private reg     │    GKE cluster        │    secrets
           ▼                       ▼                       ▼

                              YOUR LIVE APP
                          ┌─────────────────┐
                          │  LoadBalancer   │
                          │ 34.60.135.177   │
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  Users Access   │
                          │  Your Website   │
                          └─────────────────┘
```

---

## Prerequisites

Install the following tools on your computer:

- **[Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)**
- **Terraform** v1.6+
- **GitHub** account
- **Git**

### Verify installations

```bash
gcloud --version
terraform --version
git --version
```

---

## Day 1: Setup & Preparation

### 1. Create GCP Project

```bash
# Log into GCP
gcloud auth login

# Create a new project
gcloud projects create secure-cicd-demo-abdul-2026 --name="Secure CICD Demo"

# Validate the project
gcloud projects describe secure-cicd-demo-abdul-2026

# Set as active project
gcloud config set project secure-cicd-demo-abdul-2026

# Verify active project
gcloud config list
```

> **Billing:** Enable billing at https://console.cloud.google.com/billing  
> Estimated cost for testing: ~$1–2

### Useful project commands

```bash
# List all projects
gcloud projects list

# Unset the default project
gcloud config unset project

# Delete a project
gcloud projects delete secure-cicd-demo-abdul-2026 --quiet
```

---

### 2. Enable Required APIs

**Linux / macOS:**
```bash
gcloud services enable \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com
```

**Windows PowerShell:**
```powershell
gcloud services enable `
  iam.googleapis.com `
  cloudbuild.googleapis.com `
  container.googleapis.com `
  artifactregistry.googleapis.com `
  secretmanager.googleapis.com `
  servicenetworking.googleapis.com `
  cloudresourcemanager.googleapis.com
```

**Success output looks like:**
```
Operation "operations/acf.p2-912885513424-43ccd9f2-..." finished successfully.
```

This enables:

| API | Purpose |
|-----|---------|
| IAM | Identity & Access Management |
| Cloud Build | CI/CD build service |
| GKE | Google Kubernetes Engine |
| Artifact Registry | Private container image storage |
| Secret Manager | Secure secrets storage |
| Service Networking | VPC peering for private pools |
| Cloud Resource Manager | Project management |

```bash
# Verify billing is active
gcloud beta billing projects describe secure-cicd-demo-abdul-2026
```

---

### 3. Create GitHub Repository

1. Go to **GitHub.com → New repository**
2. Name: `secure-cicd-demo`
3. Visibility: Public or Private (your choice)
4. Initialize with README

```bash
# Clone to your computer
git clone https://github.com/YOUR_USERNAME/secure-cicd-demo.git
cd secure-cicd-demo
```

---

## Infrastructure Deployment

### 4. Create Terraform Files

Create these three files in your repository root:

- `main.tf`
- `variables.tf`
- `terraform.tfvars`

### 5. Deploy with Terraform

```bash
# Set up application default credentials
gcloud auth application-default login

# Verify the access token
gcloud auth application-default print-access-token

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan
# Expected: Plan: 22 to add, 0 to change, 0 to destroy.

# Deploy everything (takes 10–15 minutes for GKE)
terraform apply -auto-approve
```

---

### 6. Configure Kubernetes Workload Identity

```bash
# Get credentials for your cluster
gcloud container clusters get-credentials secure-cluster --region us-central1

# Create Kubernetes service account
kubectl create serviceaccount app-ksa

# Link KSA to GCP service account (Workload Identity)
kubectl annotate serviceaccount app-ksa \
  iam.gke.io/gcp-service-account=app-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Verify the annotation
kubectl describe serviceaccount app-ksa
```

---

## GitHub Actions Setup

### 7. Create Workflow File

Create `.github/workflows/deploy.yml` in your repository.

### 8. Add GitHub Secrets

```bash
# Get the Workload Identity Provider value
terraform output workload_identity_provider

# Get the service account email
terraform output github_service_account_email
```

Go to: **Your repo → Settings → Secrets and variables → Actions**

Add two repository secrets:

| Secret Name | Value |
|-------------|-------|
| `WIF_PROVIDER` | Output from `workload_identity_provider` |
| `GCP_SA_EMAIL` | Output from `github_service_account_email` |

---

## Sample Application Files

### `Dockerfile`

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

### `index.html`

```html
<!DOCTYPE html>
<html>
<head><title>Secure CI/CD Demo</title></head>
<body>
    <h1>🚀 Deployed via Private Cloud Build!</h1>
    <p>No internet access during build. No service account keys stored anywhere.</p>
</body>
</html>
```

### `cloudbuild.yaml`

```yaml
steps:
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials secure-cluster --region=us-central1
        kubectl create deployment my-app --image=${_IMAGE} --dry-run=client -o yaml | kubectl apply -f -
        kubectl expose deployment my-app --port=80 --type=LoadBalancer --dry-run=client -o yaml | kubectl apply -f -
```

---

## Testing the Pipeline

### 9. Push & Trigger the Pipeline

```bash
git add .
git commit -m "Initial CI/CD setup"
git push origin main
```

Watch the run at: **Your repo → Actions tab**

### 10. Verify the Deployment

```bash
# Check pod status
kubectl get pods

# Check services
kubectl get services

# Get external IP (may take 2–3 minutes)
kubectl get service my-app
```

Then open `http://<EXTERNAL_IP>/` in your browser.

---

## How Authentication Works (Zero-Trust Flow)

No passwords or long-lived keys are used. Here's the flow:

```
1. GitHub Actions  ──►  "I'm from repo: my-org/my-app"
                         [Signs a short-lived JWT via GitHub's OIDC server]

2. GCP Workload   ──►  Validates the JWT signature cryptographically
   Identity             Checks the attribute condition (only YOUR repo)

3. GCP Issues     ──►  Temporary access token (valid 1 hour)
                         [No static key ever stored or transmitted]

4. Cloud Build    ──►  Uses token to access:
                         • Artifact Registry  (push Docker image)
                         • GKE               (deploy workload)
                         • Secret Manager    (read app secrets)
```

---

## Security Layers

### Layer 1 — Workload Identity Federation (GitHub → GCP)

| Attribute | Detail |
|-----------|--------|
| **Problem solved** | No long-lived keys in GitHub Secrets |
| **Mechanism** | GitHub signs a JWT; GCP validates it cryptographically |
| **Protection** | Token expires in 1 hour; condition locks to your repo only |

### Layer 2 — Private Cloud Build Pool

| Attribute | Detail |
|-----------|--------|
| **Problem solved** | Builds can't reach the internet (prevents data exfiltration) |
| **Mechanism** | VPC with no external IP + VPC peering to Cloud Build |
| **Protection** | Even if build is compromised, attacker can't exfiltrate data |

### Layer 3 — GKE Workload Identity

| Attribute | Detail |
|-----------|--------|
| **Problem solved** | Pods access secrets without keys baked into containers |
| **Mechanism** | Kubernetes SA annotated to map to a GCP SA |
| **Protection** | Pod gets temporary credentials from the metadata server |

---

## Cost Estimate

| Service | Approximate Cost |
|---------|-----------------|
| GKE cluster (`e2-standard-2`) | ~$0.10 / hour |
| Cloud Build private pool | ~$0.003 / minute |
| Artifact Registry | ~$0.10 / GB / month |

> 💡 **Tip:** Run `terraform destroy` when not testing to avoid charges.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied on Cloud Build | Wait 2–3 minutes after `terraform apply` for IAM propagation |
| Workload Identity Pool not found | Verify the provider string matches exactly |
| Private pool stuck at `QUEUED` | VPC peering can take ~5 minutes to complete |
| `kubectl` cannot connect | Re-run `gcloud container clusters get-credentials` |

---

## Cleanup

```bash
# Destroy all provisioned resources
terraform destroy -auto-approve

# Optionally delete the entire GCP project
gcloud projects delete secure-cicd-demo-abdul-2026
```

---

## Success Checklist

- [ ] `terraform apply` completes with no errors
- [ ] GitHub Actions workflow runs successfully
- [ ] Docker image appears in Artifact Registry
- [ ] `kubectl get pods` shows a Running pod
- [ ] Service receives an external IP
- [ ] App is accessible in the browser
- [ ] Zero service account keys stored anywhere

---

## What You've Built

| Property | Detail |
|----------|--------|
| **Zero-trust CI/CD** | No long-lived credentials anywhere in the pipeline |
| **Network isolated** | Build workers have no internet egress |
| **Least privilege** | Each service holds only the permissions it needs |
| **Production ready** | Same patterns used by Google, Spotify, and Shopify |

---

*Live site: http://136.111.42.60/*
