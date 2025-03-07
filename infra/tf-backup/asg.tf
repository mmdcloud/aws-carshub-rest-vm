resource "aws_autoscaling_group" "asg" {
  name                      = "ASG"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = false
  target_group_arns         = [aws_lb_target_group.lb_target_group.arn]
  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  launch_template {
    id      = aws_launch_template.nodejs_template.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "asg_frontend" {
  name                      = "ASG_FRONTEND"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = false
  target_group_arns         = [aws_lb_target_group.lb_frontend_target_group.arn]
  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  launch_template {
    id      = aws_launch_template.nextjs_template.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "asg"
    propagate_at_launch = true
  }
}