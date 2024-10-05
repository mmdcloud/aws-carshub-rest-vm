resource "aws_lb" "lb" {
  name                       = "lb"
  internal                   = false
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb.id]
  subnets                    = aws_subnet.public_subnets[*].id
  enable_deletion_protection = false
  tags = {
    Name = "lb"
  }
}

resource "aws_lb_target_group" "lb_target_group" {
  name            = "lb-target-group"
  port            = 80
  ip_address_type = "ipv4"
  protocol        = "HTTP"

  vpc_id = aws_vpc.vpc.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    port                = 80
  }

  tags = {
    Name = "lb_target_group"
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}