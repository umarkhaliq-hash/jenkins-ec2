terraform {
  backend "s3" {
    bucket  = "ecommerce-terraform-state-bucket"
    key     = "dev/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}