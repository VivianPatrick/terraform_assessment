output "vpc_id" {
  description = "The ID of the TechCorp VPC"
  value       = aws_vpc.main.id
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer — use this to access the web app"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "Elastic (public) IP address of the Bastion host"
  value       = aws_eip.bastion.public_ip
}

output "web_server_private_ips" {
  description = "Private IP addresses of the web servers"
  value       = aws_instance.web[*].private_ip
}

output "db_server_private_ip" {
  description = "Private IP address of the database server"
  value       = aws_instance.database.private_ip
}
