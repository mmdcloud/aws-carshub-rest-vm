output "frontend_load_balancer_dns_name" {
  description = "DNS name of the public-facing Frontend Application Load Balancer"
  value       = module.carshub_frontend_lb.dns_name
}

output "backend_load_balancer_dns_name" {
  description = "DNS name of the internal Backend Application Load Balancer"
  value       = module.carshub_backend_lb.dns_name
}

output "frontend_load_balancer_ip" {
  description = "DNS name of the frontend load balancer (backward compatible alias)"
  value       = module.carshub_frontend_lb.dns_name
}

output "backend_load_balancer_ip" {
  description = "DNS name of the backend load balancer (backward compatible alias)"
  value       = module.carshub_backend_lb.dns_name
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution for media"
  value       = module.carshub_media_cloudfront_distribution.domain_name
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS MySQL database"
  value       = module.carshub_db.endpoint
}

output "vpc_id" {
  description = "VPC ID of the Carshub production VPC"
  value       = module.carshub_vpc.vpc_id
}
