# -----------------------------------------------------------------------------------------
# EC2 IAM Role & Instance Profile
# -----------------------------------------------------------------------------------------
module "iam_instance_profile_role" {
  source             = "../../../modules/iam"
  role_name          = "iam-instance-profile-role-${var.env}-${var.region}"
  role_description   = "Instance Profile Role for EC2 Instances"
  policy_name        = "iam-instance-profile-policy-${var.env}-${var.region}"
  policy_description = "IAM policy for EC2 instance profile"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.carshub_media_bucket.arn,
          "${module.carshub_media_bucket.arn}/*"
        ]
        Effect = "Allow"
      },
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          module.carshub_db_credentials.arn,
          "${module.carshub_db_credentials.arn}*"
        ]
        Effect = "Allow"
      }
    ]
  })
  tags = {
    Name        = "iam-instance-profile-role-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = module.iam_instance_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = module.iam_instance_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile-${var.env}-${var.region}"
  role = module.iam_instance_profile_role.name
}

# -----------------------------------------------------------------------------------------
# Launch Templates
# -----------------------------------------------------------------------------------------
# Carshub frontend instance template
module "carshub_frontend_launch_template" {
  source                               = "../../../modules/launch_template"
  name                                 = "carshub_frontend_launch_template_${var.env}"
  description                          = "carshub_frontend_launch_template_${var.env}"
  ebs_optimized                        = false
  image_id                             = data.aws_ami.ubuntu.id
  instance_type                        = "t3.medium"
  instance_initiated_shutdown_behavior = "stop"
  instance_profile_name                = aws_iam_instance_profile.iam_instance_profile.name
  network_interfaces = [
    {
      associate_public_ip_address = false
      security_groups             = [module.carshub_asg_frontend_sg.id]
    }
  ]
  user_data = base64encode(templatefile("${path.module}/../../../scripts/user_data_frontend.sh", {
    BASE_URL = "http://${module.carshub_backend_lb.dns_name}"
    CDN_URL  = module.carshub_media_cloudfront_distribution.domain_name
  }))
}

# Carshub backend instance template
module "carshub_backend_launch_template" {
  source                               = "../../../modules/launch_template"
  name                                 = "carshub_backend_launch_template_${var.env}"
  description                          = "carshub_backend_launch_template_${var.env}"
  ebs_optimized                        = false
  image_id                             = data.aws_ami.ubuntu.id
  instance_type                        = "t3.medium"
  instance_initiated_shutdown_behavior = "stop"
  instance_profile_name                = aws_iam_instance_profile.iam_instance_profile.name
  network_interfaces = [
    {
      associate_public_ip_address = false
      security_groups             = [module.carshub_asg_backend_sg.id]
    }
  ]
  user_data = base64encode(templatefile("${path.module}/../../../scripts/user_data_backend.sh", {
    DB_PATH     = tostring(split(":", module.carshub_db.endpoint)[0])
    SECRET_NAME = module.carshub_db_credentials.name
    REGION      = var.region
    DB_NAME     = var.db_name
    UN          = ""
    CREDS       = ""
  }))
}

# -----------------------------------------------------------------------------------------
# Auto Scaling Groups
# -----------------------------------------------------------------------------------------
module "carshub_frontend_asg" {
  source                    = "../../../modules/auto_scaling_group"
  name                      = "carshub_frontend_asg_${var.env}"
  min_size                  = 3
  max_size                  = 50
  desired_capacity          = 3
  health_check_grace_period = 600
  health_check_type         = "ELB"
  force_delete              = false
  target_group_arns         = [module.carshub_frontend_lb.target_groups["carshub_frontend_lb_target_group"].arn]
  vpc_zone_identifier       = module.carshub_vpc.private_subnets
  launch_template_id        = module.carshub_frontend_launch_template.id
  launch_template_version   = "$Latest"
}

resource "aws_autoscaling_policy" "carshub_frontend_asg_cpu_policy" {
  name                   = "carshub-frontend-cpu-scaling-policy-${var.env}"
  autoscaling_group_name = module.carshub_frontend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

module "carshub_backend_asg" {
  source                    = "../../../modules/auto_scaling_group"
  name                      = "carshub_backend_asg_${var.env}"
  min_size                  = 3
  max_size                  = 50
  desired_capacity          = 3
  health_check_grace_period = 600
  health_check_type         = "ELB"
  force_delete              = false
  target_group_arns         = [module.carshub_backend_lb.target_groups["carshub_backend_lb_target_group"].arn]
  vpc_zone_identifier       = module.carshub_vpc.private_subnets
  launch_template_id        = module.carshub_backend_launch_template.id
  launch_template_version   = "$Latest"
}

resource "aws_autoscaling_policy" "carshub_backend_asg_cpu_policy" {
  name                   = "carshub-backend-cpu-scaling-policy-${var.env}"
  autoscaling_group_name = module.carshub_backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
