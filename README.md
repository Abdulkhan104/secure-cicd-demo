                                                     # Secure CI/CD Pipeline on GCP #

A production-grade, zero-trust CI/CD pipeline on Google Cloud Platform using Workload Identity Federation, private Cloud Build, and GKE.



## ARCHITECTURE

┌────────────────────────────────────────────────────────────────────────────────────┐
│                              YOUR COMPLETE PIPELINE                                │
└────────────────────────────────────────────────────────────────────────────────────┘

     YOU PUSH CODE                        AUTHENTICATION                         BUILD
         │                                      │                                  │
         ▼                                      ▼                                  ▼
┌─────────────────┐                  ┌─────────────────┐                  ┌─────────────────┐
│   GitHub        │                  │   Workload      │                  │   Cloud Build   │
│   Repository    │                  │   Identity      │                  │   Private Pool  │
│                 │                  │   Federation    │                  │                 │
│  main branch    │                  │                 │                  │  NO INTERNET!   │
└────────┬────────┘                  └────────  ───────┘                  └────────┬────────┘
         │                                      │                                  │
         │ 1. You push code                     │ 2. GitHub proves                 │ 3. Builds container
         │    to GitHub                         │    identity without              │    in isolation
         │                                      │    any passwords                 │
         │                                      │                                  │
         ▼                                      ▼                                  ▼

      STORAGE                              DEPLOYMENT                           SECRETS
         │                                      │                                  │
         ▼                                      ▼                                  ▼
┌─────────────────┐                  ┌─────────────────┐                  ┌───────────────┐
│   Artifact      │                  │   GKE Cluster   │                  │   Secret      │
│   Registry      │                  │   (Private)     │                  │   Manager     │
│                 │                  │                 │                  │               │
│  Docker images  │                  │  3 worker nodes │                  │  API keys     │
│  stored safely  │                  │                 │                  │  database cred│
└────────┬────────┘                  └────────┬────────┘                  └──────┬────────┘
         │                                    │                                  │
         │ 4. Image pushed                    │ 5. Deployed to                   │ 6. App gets
         │    to private registry             │    GKE cluster                   │    secrets
         │                                    │                                  │
         ▼                                    ▼                                  ▼

                                        YOUR LIVE APP
                                    ┌─────────────────┐
                                    │   LoadBalancer  │
                                    │   34.60.135.177 │
                                    └────────┬────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │   Users Access  │
                                    │   Your Website  │
                                    └─────────────────┘


# 1. Install these tools on your computer
- Google Cloud SDK (gcloud)
   ->https://docs.cloud.google.com/sdk/docs/install-sdk
   ->Search I Taskbar ->"Goggle Cloud SDK shell"
   -> "gcloud auth login" enter the command for authentications purpose 
   -> "gcloud projects list" checking the project 
   -> "gcloud config set project (PROJECT_ID)" Set your project by default
   -> "gcloud config list" Checking purpose you selected or not 
   -> "gcloud config unset project" If you want to unselect the project
   -> "gcloud projects delete abktechno --quiet" If you want to delete the project 

- Terraform (v1.6+)
- GitHub account  
- Git

# 2. Verify installations
gcloud --version
terraform --version
git --version

 ************************************************* Day 1: Setup & Preparation  ************************************************
  
  
  1.  Create GCP Project 

# Log into your personal GCP account
gcloud auth login -> SELECT YOUR ACCOUNT 


# Create a new project for testing
gcloud projects create secure-cicd-demo-abdul-2026 --name="Secure CICD Demo" -> crate your project
gcloud projects describe secure-cicd-demo-abdul-2026                         -> For Validate your project
gcloud config set project gen-lang-client-0965257658                         -> For Set as active project



# Enable billing (required, but costs will be minimal ~$1-2 for testing)
# Go to: https://console.cloud.google.com/billing

*************************************************  Enable Required APIs ***************************************************

# Copy and run this entire block
gcloud services enable \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com

gcloud services enable `
  iam.googleapis.com `
  cloudbuild.googleapis.com `
  container.googleapis.com `
  artifactregistry.googleapis.com `
  secretmanager.googleapis.com `
  servicenetworking.googleapis.com `
  cloudresourcemanager.googleapis.com

PS E:\TaskProjectGCP\secure-cicd-demo> gcloud services enable `
>>   iam.googleapis.com `
>>   cloudbuild.googleapis.com `
>>   container.googleapis.com `
>>   artifactregistry.googleapis.com `
>>   secretmanager.googleapis.com `
>>   servicenetworking.googleapis.com `
>>   cloudresourcemanager.googleapis.com

if done look like thsi :- " Operation "operations/acf.p2-912885513424-43ccd9f2-f155-4e5d-8edf-ad1689f23e54" finished successfully."
PS E:\TaskProjectGCP\secure-cicd-demo> 
PS E:\TaskProjectGCP\secure-cicd-demo> 

<-if all is done look like this ->

What this enables

You’ll get access to:

IAM
Cloud Build
Google Kubernetes Engine
Artifact Registry
Secret Manager
Service Networking
Cloud Resource Manager

"gcloud beta billing projects describe secure-cicd-demo-abdul-2026" -> enable your billling

That covers most CI/CD + infra automation scenarios.

gcloud services enable secretmanager.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com


 ******************************************************** Create GitHub Repository ********************************************

# Go to GitHub.com → New repository
# Name: secure-cicd-demo
# Make it Public (or Private - your choice)
# Initialize with README

# 2. Clone it to your computer
git clone https://github.com/YOUR_USERNAME/secure-cicd-demo.git
cd secure-cicd-demo

===================================================== Then ->>>  Infrastructure Deployment ===============================================


******************************************************   Create Terraform Files  *************************************************
Create these files in your repository:
File 1: main.tf (Complete working version)
File 2: variable.tf
File 3: terraform.tfvars (CREATE THIS FILE)


*****************************************************   Deploy with Terraform   *************************************************

# Initialize Terraform
terraform init

gcloud auth application-default login

PS E:\TaskProjectGCP\secure-cicd-demo> gcloud auth application-default print-access-token
PS E:\TaskProjectGCP\secure-cicd-demo>  --> 
******its important to default access******



# See what will be created
terraform plan

Plan: 22 to add, 0 to change, 0 to destroy.

# Deploy everything
terraform apply -auto-approve

# This takes 10-15 minutes (GKE cluster creation)
# Wait for completion!


*************************************************** Configure Kubernetes Workload Identity ***************************************



# Get credentials for your cluster
gcloud container clusters get-credentials secure-cluster --region us-central1

# Create Kubernetes service account
kubectl create serviceaccount app-ksa

# Link KSA to GCP service account (Workload Identity)
kubectl annotate serviceaccount app-ksa \
  iam.gke.io/gcp-service-account=app-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Verify
kubectl describe serviceaccount app-ksa

================================================== GitHub Actions Setup =====================================================================


 ************************************************ Create GitHub Actions Workflow  ************************************************************

Create file: .github/workflows/deploy.yml

*************************************************   <<<<  Add GitHub Secrets >>>>>>       ***************************************************

# Get the Workload Identity Provider value
terraform output workload_identity_provider

# Get the service account email
terraform output github_service_account_email

# Add these as secrets in GitHub:
# Go to: Your repo → Settings → Secrets and variables → Actions
# Add two secrets:
# 1. WIF_PROVIDER = (value from above)
# 2. GCP_SA_EMAIL = (value from above)

 ********************************************************* Create Sample App      *******************************************************

Create Dockerfile:

# Dockerfile
FROM nginx:alpine -><<<< use latest OS  >>>>
COPY index.html /usr/share/nginx/html/index.html #### <<paste your index.html to nginx root >>
EXPOSE 80


Create index.html:

<!-- index.html -->
<!DOCTYPE html>
<html>
<head><title>Secure CI/CD Demo</title></head>
<body>
    <h1> Deployed via Private Cloud Build!</h1>
    <p>No internet access, no service account keys!</p>
</body>
</html>


Create cloudbuild.yaml:

# cloudbuild.yaml
steps:
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud container clusters get-credentials secure-cluster --region=us-central1
        kubectl create deployment my-app --image=${_IMAGE} --dry-run=client -o yaml | kubectl apply -f -
        kubectl expose deployment my-app --port=80 --type=LoadBalancer --dry-run=client -o yaml | kubectl apply -f -


Testing Your Pipeline


***************************************************** Run the Pipeline  *********************************************************



# Commit and push your code
git add .
git commit -m "Initial CI/CD setup"
git push origin main

# Watch the GitHub Action run:
# Go to: Your repo → Actions tab


************************************   Step 11: Verify Everything Works **********************************************************


# Check if deployment succeeded
kubectl get pods
kubectl get services

# Get the external IP (might take 2-3 minus)
kubectl get service my-app

=====================================  Documentation: Authentication Flow (Simple Version) =========================================

              
 How Does Authentication Work (No Passwords/Keys)?
Imagine a VIP concert with no paper tickets:



1. GitHub Actions → "I'm from the official band (repo: my-app)"
   [Shows digital ID from GitHub's secure server]

2. GCP's Security Check → Checks digital signature
   "Yes, this really is from GitHub"
   "And you're allowed to enter (attribute_condition)"

3. GCP Says → "Here's a temporary backstage pass (valid 1 hour)"
   [No physical key ever changes hands!]

4. Cloud Build → Uses pass to access:
   - Artifact Registry (private fridge)
   - GKE (deploy to warehouse)
   - Secret Manager (read secrets)




Three Security Layers Explained
Layer 1: GitHub → GCP (Workload Identity Federation)
Problem solved: No long-lived keys stored in GitHub secrets

How: GitHub signs a JWT token, Google validates it cryptographically

Security: Token expires in 1 hour, condition ensures only YOUR repo

Layer 2: Private Cloud Build Pool
Problem solved: Builds can't reach internet (prevents data theft)

How: VPC with no external IP + peering to Cloud Build

Security: Even if compromised, attacker can't exfiltrate data

Layer 3: GKE Workload Identity
Problem solved: Pods need secrets without storing keys in containers

How: Kubernetes SA maps to GCP SA via annotation

Security: Pod automatically gets temporary credentials from metadata server

 
 Clean Up (Important!)
bash
# Delete all resources when done to avoid charges
terraform destroy -auto-approve

# Delete the GCP project (optional)
gcloud projects delete secure-cicd-demo

 
 Common Issues & Fixes :->
Issue	Solution
Permission denied on Cloud Build	Wait 2-3 minutes after terraform apply for IAM propagation
Workload Identity Pool not found	Check the provider string matches exactly
Private pool stuck at QUEUED	Check VPC peering is complete (takes ~5 minutes)
kubectl cannot connect	Run gcloud container clusters get-credentials again

 
 Success Checklist
Terraform apply completes without errors

GitHub Action runs successfully

Docker image appears in Artifact Registry

kubectl get pods shows running pod

Service gets external IP

You can access the app in browser

No service account keys stored anywhere

 
 
 =====================================    Cost Estimate (For Personal Account)  =================================

 
Service	Cost
GKE cluster (e2-standard-2)	        ~$0.10/hour
Cloud Build private pool          	~$0.003/minute
Artifact Registry                 	~$0.10/GB/month
Pro tip: Destroy resources when not testing (terraform destroy)

 
 What You've Built
    Zero-trust CI/CD - No long-lived credentials
    Network isolated - Builds have no internet
    Least privilege - Each service has minimum permissions
    Production ready - Same patterns used by Google, Spotify, Shopify



ACCESS THE SITE :- http://136.111.42.60/


