output "backend_load_balancer_ip" {
  value = aws_lb.lb.dns_name
}

output "frontend_load_balancer_ip" {
  value = aws_lb.lb_frontend.dns_name
}