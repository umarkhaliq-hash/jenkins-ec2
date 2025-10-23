# E-commerce Application Infrastructure

## Architecture Overview
- **GitHub** → **Jenkins** → **ECR** → **ECS** + **EC2**
- **LGTM Stack** (Loki, Grafana, Tempo, Mimir) for monitoring
- **Terraform** for infrastructure as code

## Deployment Steps

### 1. Initial Setup (First Time Only)
```bash
# Create S3 bucket for state
cd terraform
terraform init
terraform plan
terraform apply -target=aws_s3_bucket.terraform_state
```

### 2. Configure Backend
```bash
# After S3 bucket is created, run:
terraform init -migrate-state
```

### 3. Deploy Infrastructure
```bash
# Copy and modify variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy everything
terraform plan
terraform apply
```

### 4. Access Applications
- **Application**: `http://<EC2_PUBLIC_IP>:3000`
- **Grafana**: `http://<EC2_PUBLIC_IP>:3001` (admin/admin123)
- **Prometheus**: `http://<EC2_PUBLIC_IP>:9090`

### 5. Jenkins Pipeline Setup
1. Create Jenkins credentials:
   - `ecr-repository-url`: ECR repository URL
   - `aws-account-id`: Your AWS account ID
2. Create pipeline job using Jenkinsfile
3. Configure webhook in GitHub

## Infrastructure Components

### AWS Resources Created:
- **VPC** with public subnets
- **ECR** repository for container images
- **ECS** cluster with Fargate service
- **EC2** t3.micro instance with Docker
- **Security Groups** for network access
- **IAM** roles and policies
- **S3** bucket for Terraform state

### Monitoring Stack (LGTM):
- **Loki**: Log aggregation
- **Grafana**: Visualization and dashboards
- **Tempo**: Distributed tracing
- **Mimir**: Metrics storage
- **Prometheus**: Metrics collection

## Security Features:
- S3 bucket encryption enabled
- ECR image scanning
- Security groups with minimal access
- IAM roles with least privilege

## Ports:
- **3000**: Application
- **3001**: Grafana
- **9090**: Prometheus
- **3100**: Loki

## Commands:
```bash
# Update application on EC2
ssh -i ~/.ssh/ecommerce-key.pem ec2-user@<EC2_IP> 'bash /home/ec2-user/update-app.sh'

# View logs
ssh -i ~/.ssh/ecommerce-key.pem ec2-user@<EC2_IP> 'cd /home/ec2-user/app && docker-compose logs -f'
```