output "backend_load_balancer_ip" {
  value = module.carshub_backend_lb.lb_dns_name
}

output "frontend_load_balancer_ip" {
  value = module.carshub_frontend_lb.lb_dns_name
}
