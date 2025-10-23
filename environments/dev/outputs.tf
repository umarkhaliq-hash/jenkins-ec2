output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = module.ec2.public_ip
}

output "prestashop_store_url" {
  description = "PrestaShop Store URL (Docker)"
  value       = "http://${module.ec2.public_ip}:3000"
}

output "prestashop_admin_url" {
  description = "PrestaShop Admin URL"
  value       = "http://${module.ec2.public_ip}:3000/admin"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${module.ec2.public_ip}:3001"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${module.ec2.public_ip}:9090"
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${module.ec2.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ssh-keys/${var.project_name}-key ubuntu@${module.ec2.public_ip}"
}