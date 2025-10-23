terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "ecommerce-terraform-state-bucket"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Create SSH Key Pair
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = file("${path.module}/../../ssh-keys/${var.project_name}-key.pub")
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# IAM Module
module "iam" {
  source = "../../modules/iam"
  
  project_name = var.project_name
  environment  = var.environment
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"
  
  project_name = var.project_name
  environment  = var.environment
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"
  
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.public_subnet_ids
  security_group_id    = module.security.ecs_security_group_id
  execution_role_arn   = module.iam.ecs_execution_role_arn
  ecr_repository_url   = module.ecr.repository_url
  aws_region           = var.aws_region
}

# EC2 Module
module "ec2" {
  source = "../../modules/ec2"
  
  project_name         = var.project_name
  environment          = var.environment
  instance_type        = var.instance_type
  key_name             = aws_key_pair.main.key_name
  vpc_id               = module.vpc.vpc_id
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_id    = module.security.ec2_security_group_id
  instance_profile     = module.iam.ec2_instance_profile_name
  ecr_repository_url   = module.ecr.repository_url
  aws_region           = var.aws_region
}