# E-commerce Infrastructure Deployment Guide

## Manual Deployment Steps

### Step 1: Create S3 Bucket for Terraform State
```bash
# Navigate to project root
cd /Users/mac/Documents/ArgoCD/ecomerce-ec2

# Initialize and create S3 bucket
terraform init
terraform apply -target=aws_s3_bucket.terraform_state -auto-approve
```

### Step 2: Configure Backend and Migrate State
```bash
# Navigate to dev environment
cd environments/dev

# Initialize with backend migration
terraform init -migrate-state
```

### Step 3: Deploy Infrastructure
```bash
# Plan deployment
terraform plan

# Apply infrastructure
terraform apply -auto-approve
```

## What Gets Deployed

### AWS Resources:
- ✅ **VPC** with public subnets
- ✅ **ECR** repository for container images
- ✅ **ECS** Fargate cluster and service
- ✅ **EC2** t3.micro instance
- ✅ **Security Groups** (ports: 22, 80, 3000, 3001, 8080, 9090, 3100)
- ✅ **IAM** roles and policies
- ✅ **S3** bucket with encryption
- ✅ **SSH Key Pair** (auto-generated)

### Services on EC2:
- ✅ **Jenkins** (port 8080) - CI/CD pipeline
- ✅ **Application** (port 3000) - Your ecommerce app
- ✅ **Grafana** (port 3001) - Monitoring dashboard
- ✅ **Prometheus** (port 9090) - Metrics collection
- ✅ **Loki** (port 3100) - Log aggregation
- ✅ **Promtail** - Log shipping

## Access URLs (After Deployment)

```bash
# Get outputs
terraform output
```

- **Application**: `http://<EC2_IP>:3000`
- **Jenkins**: `http://<EC2_IP>:8080`
- **Grafana**: `http://<EC2_IP>:3001` (admin/admin123)
- **Prometheus**: `http://<EC2_IP>:9090`

## Jenkins Setup (After Infrastructure is Ready)

### 1. Get Jenkins Initial Password
```bash
# SSH to EC2
ssh -i ssh-keys/ecommerce-key ec2-user@<EC2_IP>

# Get Jenkins password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 2. Configure Jenkins
1. Open `http://<EC2_IP>:8080`
2. Enter initial admin password
3. Install suggested plugins
4. Create admin user

### 3. Add Jenkins Credentials
- Go to "Manage Jenkins" → "Credentials"
- Add these credentials:
  - `ecr-repository-url`: Your ECR repository URL
  - `aws-account-id`: Your AWS account ID

### 4. Create Pipeline Job
1. New Item → Pipeline
2. Use Pipeline script from SCM
3. Repository URL: Your GitHub repo
4. Script Path: `Jenkinsfile`

## CI/CD Flow

**GitHub** → **Jenkins** → **Build Docker** → **Push to ECR** → **Deploy to ECS** → **Update EC2**

## File Structure Created

```
ecomerce-ec2/
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── modules/
│   ├── vpc/
│   ├── security/
│   ├── iam/
│   ├── ecr/
│   ├── ecs/
│   └── ec2/
├── user_data/
│   └── ec2_init.sh
├── ssh-keys/
│   ├── ecommerce-key
│   └── ecommerce-key.pub
├── s3-backend-setup.tf
├── Jenkinsfile
└── Dockerfile
```

## Commands Summary

```bash
# 1. Create S3 bucket
terraform init
terraform apply -target=aws_s3_bucket.terraform_state -auto-approve

# 2. Configure backend
cd environments/dev
terraform init -migrate-state

# 3. Deploy everything
terraform plan
terraform apply -auto-approve

# 4. Get outputs
terraform output
```

## Troubleshooting

- Wait 5-10 minutes after deployment for EC2 initialization
- Check EC2 user data logs: `/var/log/cloud-init-output.log`
- Jenkins takes 2-3 minutes to start after EC2 boot
- All services run in Docker containers on EC2