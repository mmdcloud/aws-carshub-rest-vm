output "backend_load_balancer_ip" {
  value = module.carshub_backend_lb.dns_name
}

output "frontend_load_balancer_ip" {
  value = module.carshub_frontend_lb.dns_name
}