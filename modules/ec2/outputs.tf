output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "EC2 instance public IP"
  value       = aws_eip.app_server.public_ip
}

output "public_dns" {
  description = "EC2 instance public DNS"
  value       = aws_instance.app_server.public_dns
}

output "private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.app_server.private_ip
}