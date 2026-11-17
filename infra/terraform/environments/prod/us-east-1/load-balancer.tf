# -----------------------------------------------------------------------------------------
# Load Balancer Configuration
# -----------------------------------------------------------------------------------------
module "carshub_frontend_lb" {
  source                     = "terraform-aws-modules/alb/aws"
  version                    = "~> 9.0"
  name                       = "frontend-lb-${var.env}-${var.region}"
  load_balancer_type         = "application"
  vpc_id                     = module.carshub_vpc.vpc_id
  subnets                    = module.carshub_vpc.public_subnets
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  ip_address_type            = "ipv4"
  internal                   = false
  security_groups = [
    module.carshub_frontend_lb_sg.id
  ]
  access_logs = {
    bucket = module.carshub_frontend_lb_logs.bucket
  }
  listeners = {
    carshub_frontend_lb_http_listener = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "carshub_frontend_lb_target_group"
      }
    }
  }
  target_groups = {
    carshub_frontend_lb_target_group = {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        path                = "/auth/signin"
        port                = "traffic-port"
        protocol            = "HTTP"
        unhealthy_threshold = 3
      }
      create_attachment = false
    }
  }
  tags = {
    Name        = "frontend-lb-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}

module "carshub_backend_lb" {
  source                     = "terraform-aws-modules/alb/aws"
  version                    = "~> 9.0"
  name                       = "backend-lb-${var.env}-${var.region}"
  load_balancer_type         = "application"
  vpc_id                     = module.carshub_vpc.vpc_id
  subnets                    = module.carshub_vpc.private_subnets
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  ip_address_type            = "ipv4"
  internal                   = true
  security_groups = [
    module.carshub_backend_lb_sg.id
  ]
  access_logs = {
    bucket = module.carshub_backend_lb_logs.bucket
  }
  listeners = {
    carshub_backend_lb_http_listener = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "carshub_backend_lb_target_group"
      }
    }
  }
  target_groups = {
    carshub_backend_lb_target_group = {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        unhealthy_threshold = 3
      }
      create_attachment = false
    }
  }
  tags = {
    Name        = "backend-lb-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}
