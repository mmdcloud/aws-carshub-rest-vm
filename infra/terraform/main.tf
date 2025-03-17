# Registering vault provider
data "vault_generic_secret" "rds" {
  path = "secret/rds"
}

# VPC Configuration
module "carshub_vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "carshub_vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "carshub_vpc_igw"
}

# Security Group
module "carshub_frontend_lb_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_frontend_lb_sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "carshub_backend_lb_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_backend_lb_sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "carshub_asg_frontend_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_asg_frontend_sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = []
      security_groups = [module.carshub_frontend_lb_sg.id]
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "carshub_asg_backend_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_asg_backend_sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = []
      security_groups = [module.carshub_backend_lb_sg.id]
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# RDS Security Group
module "carshub_rds_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_rds_sg"
  ingress = [
    {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = []
      security_groups = [module.carshub_asg_backend_sg.id]
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Public Subnets
module "carshub_public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "carshub public subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "us-east-1a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "us-east-1c"
    }
  ]
  vpc_id                  = module.carshub_vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "carshub_private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "carshub private subnet"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "us-east-1d"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "us-east-1e"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "us-east-1f"
    }
  ]
  vpc_id                  = module.carshub_vpc.vpc_id
  map_public_ip_on_launch = false
}

# Carshub Public Route Table
module "carshub_public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "carshub public route table"
  subnets = module.carshub_public_subnets.subnets[*]
  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = module.carshub_vpc.igw_id
    }
  ]
  vpc_id = module.carshub_vpc.vpc_id
}

# Carshub Private Route Table
module "carshub_private_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "carshub public route table"
  subnets = module.carshub_private_subnets.subnets[*]
  routes  = []
  vpc_id  = module.carshub_vpc.vpc_id
}

# Secrets Manager
module "carshub_db_credentials" {
  source                  = "./modules/secrets-manager"
  name                    = "carshub_rds_secrets"
  description             = "carshub_rds_secrets"
  recovery_window_in_days = 0
  secret_string = jsonencode({
    username = tostring(data.vault_generic_secret.rds.data["username"])
    password = tostring(data.vault_generic_secret.rds.data["password"])
  })
}

# RDS Instance
module "carshub_db" {
  source               = "./modules/rds"
  db_name              = "carshub"
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  multi_az             = false
  parameter_group_name = "default.mysql8.0"
  username             = tostring(data.vault_generic_secret.rds.data["username"])
  password             = tostring(data.vault_generic_secret.rds.data["password"])
  subnet_group_name    = "carshub_rds_subnet_group"
  subnet_group_ids = [
    module.carshub_public_subnets.subnets[0].id,
    module.carshub_public_subnets.subnets[1].id
  ]
  vpc_security_group_ids = [module.carshub_rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# S3 buckets
module "carshub_media_bucket" {
  source      = "./modules/s3"
  bucket_name = "carshubmediabucket"
  objects = [
    {
      key    = "images/"
      source = ""
    },
    {
      key    = "documents/"
      source = ""
    }
  ]
  versioning_enabled = "Enabled"
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  bucket_policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "PolicyForCloudFrontPrivateContent",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontServicePrincipal",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "${module.carshub_media_bucket.arn}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "${module.carshub_media_cloudfront_distribution.arn}"
          }
        }
      }
    ]
  })
  force_destroy = true
  bucket_notification = {
    queue = [
      {
        queue_arn = module.carshub_media_events_queue.arn
        events    = ["s3:ObjectCreated:*"]
      }
    ]
    lambda_function = [
      # {
      #   lambda_function_arn = module.carshub_media_update_function.arn
      #   events              = ["s3:ObjectCreated:*"]
      # }
    ]
  }
}

module "carshub_media_update_function_code" {
  source      = "./modules/s3"
  bucket_name = "carshubmediaupdatefunctioncode"
  objects = [
    {
      key    = "lambda.zip"
      source = "./files/lambda.zip"
    }
  ]
  bucket_policy = ""
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  versioning_enabled = "Enabled"
  force_destroy      = true
}

module "carshub_media_update_function_code_signed" {
  source             = "./modules/s3"
  bucket_name        = "carshubmediaupdatefunctioncodesigned"
  versioning_enabled = "Enabled"
  force_destroy      = true
  bucket_policy      = ""
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
}

# Lambda Layer for storing dependencies
resource "aws_lambda_layer_version" "python_layer" {
  filename            = "./files/python.zip"
  layer_name          = "python"
  compatible_runtimes = ["python3.12"]
}

# # Signing profile
# module "carshub_signing_profile" {
#   source                           = "./modules/signing-profile"
#   platform_id                      = "AWSLambda-SHA384-ECDSA"
#   signature_validity_value         = 5
#   signature_validity_type          = "YEARS"
#   ignore_signing_job_failure       = true
#   untrusted_artifact_on_deployment = "Warn"
#   s3_bucket_key                    = "lambda.zip"
#   s3_bucket_source                 = module.carshub_media_update_function_code.bucket
#   s3_bucket_version                = module.carshub_media_update_function_code.objects[0].version_id
#   s3_bucket_destination            = module.carshub_media_update_function_code_signed.bucket
# }

# SQS Queue for buffering S3 events
module "carshub_media_events_queue" {
  source                        = "./modules/sqs"
  queue_name                    = "carshub-media-events-queue"
  delay_seconds                 = 90
  maxReceiveCount               = 5
  dlq_message_retention_seconds = 86400
  dlq_name                      = "carshub-media-events-dlq"
  max_message_size              = 2048
  message_retention_seconds     = 86400
  visibility_timeout_seconds    = 0
  receive_wait_time_seconds     = 0
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:*:carshub-media-events-queue"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.carshub_media_bucket.arn
          }
        }
      }
    ]
  })
}

# Lambda IAM  Role
module "carshub_media_update_function_iam_role" {
  source             = "./modules/iam"
  role_name          = "carshub_media_update_function_iam_role"
  role_description   = "carshub_media_update_function_iam_role"
  policy_name        = "carshub_media_update_function_iam_policy"
  policy_description = "carshub_media_update_function_iam_policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:*:*:*",
                "Effect": "Allow"
            },
            {
              "Effect": "Allow",
              "Action": "secretsmanager:GetSecretValue",
              "Resource": "${module.carshub_db_credentials.arn}"
            },
            {
                "Action": "s3:*",
                "Effect": "Allow",
                "Resource": "${module.carshub_media_bucket.arn}/*"
            },
            {
              "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
              ],
              "Effect"   : "Allow",
              "Resource" : "${module.carshub_media_events_queue.arn}"
            }
        ]
    }
    EOF
}

# # SQS Queue for buffering S3 events
# module "carshub_media_events_queue" {
#   source                        = "./modules/sqs"
#   queue_name                    = "carshub-media-events-queue"
#   delay_seconds                 = 90
#   deadLetterTargetArn           = ""
#   delMaxReceiveCount            = ""
#   dlq_message_retention_seconds = ""
#   dlq_name                      = ""
#   max_message_size              = 2048
#   message_retention_seconds     = 86400
#   visibility_timeout_seconds    = 0
#   receive_wait_time_seconds     = 0
# }

# Lambda function to update media metadata in RDS database
module "carshub_media_update_function" {
  source        = "./modules/lambda"
  function_name = "carshub_media_update"
  role_arn      = module.carshub_media_update_function_iam_role.arn
  permissions = [
    # {
    #   statement_id = "AllowExecutionFromS3Bucket"
    #   action       = "lambda:InvokeFunction"
    #   principal    = "s3.amazonaws.com"
    #   source_arn   = module.carshub_media_bucket.arn
    # }
  ]
  env_variables = {
    SECRET_NAME = module.carshub_db_credentials.name
    DB_HOST     = tostring(split(":", module.carshub_db.endpoint)[0])
    DB_NAME     = var.db_name
    REGION      = var.region
  }
  handler   = "lambda.lambda_handler"
  runtime   = "python3.12"
  s3_bucket = module.carshub_media_update_function_code.bucket
  s3_key    = "lambda.zip"
  layers    = [aws_lambda_layer_version.python_layer.arn]
  # code_signing_config_arn = module.carshub_signing_profile.config_arn
}

# Cloudfront distribution
module "carshub_media_cloudfront_distribution" {
  source                                = "./modules/cloudfront"
  distribution_name                     = "carshub_media_cdn"
  oac_name                              = "carshub_media_cdn_oac"
  oac_description                       = "carshub_media_cdn_oac"
  oac_origin_access_control_origin_type = "s3"
  oac_signing_behavior                  = "always"
  oac_signing_protocol                  = "sigv4"
  enabled                               = true
  origin = [
    {
      origin_id           = "carshub_media_origin"
      domain_name         = "carshub_media_origin.s3.${var.region}.amazonaws.com"
      connection_attempts = 3
      connection_timeout  = 10
    }
  ]
  compress                       = true
  smooth_streaming               = false
  target_origin_id               = "carshub_media_origin"
  allowed_methods                = ["GET", "HEAD"]
  cached_methods                 = ["GET", "HEAD"]
  viewer_protocol_policy         = "redirect-to-https"
  min_ttl                        = 0
  default_ttl                    = 0
  max_ttl                        = 0
  price_class                    = "PriceClass_200"
  forward_cookies                = "all"
  cloudfront_default_certificate = true
  geo_restriction_type           = "none"
  query_string                   = true
}

# EC2 IAM Instance Profile
data "aws_iam_policy_document" "instance_profile_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "instance_profile_iam_role" {
  name               = "instance-profile-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_profile_assume_role.json
}

data "aws_iam_policy_document" "instance_profile_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance_profile_s3_policy" {
  role   = aws_iam_role.instance_profile_iam_role.name
  policy = data.aws_iam_policy_document.instance_profile_policy_document.json
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = aws_iam_role.instance_profile_iam_role.name
}

# Carshub frontend instance template
module "carshub_frontend_launch_template" {
  source                               = "./modules/launch_template"
  name                                 = "carshub_frontend_launch_template"
  description                          = "carshub_frontend_launch_template"
  ebs_optimized                        = false
  image_id                             = "ami-005fc0f236362e99f"
  instance_type                        = "t2.micro"
  instance_initiated_shutdown_behavior = "stop"
  instance_profile_name                = aws_iam_instance_profile.iam_instance_profile.name
  key_name                             = "madmaxkeypair"
  network_interfaces = [
    {
      associate_public_ip_address = true
      security_groups             = [module.carshub_asg_frontend_sg.id]
    }
  ]
  user_data = base64encode(templatefile("${path.module}/scripts/user_data_frontend.sh", {
    BASE_URL = "http://${module.carshub_backend_lb.lb_dns_name}"
    CDN_URL  = module.carshub_media_cloudfront_distribution.domain_name
  }))
}

# Carshub backend instance template
module "carshub_backend_launch_template" {
  source                               = "./modules/launch_template"
  name                                 = "carshub_backend_launch_template"
  description                          = "carshub_backend_launch_template"
  ebs_optimized                        = false
  image_id                             = "ami-005fc0f236362e99f"
  instance_type                        = "t2.micro"
  instance_initiated_shutdown_behavior = "stop"
  instance_profile_name                = aws_iam_instance_profile.iam_instance_profile.name
  key_name                             = "madmaxkeypair"
  network_interfaces = [
    {
      associate_public_ip_address = true
      security_groups             = [module.carshub_asg_backend_sg.id]
    }
  ]
  user_data = base64encode(templatefile("${path.module}/scripts/user_data_backend.sh", {
    DB_PATH = tostring(split(":", module.carshub_db.endpoint)[0])
    UN      = tostring(data.vault_generic_secret.rds.data["username"])
    CREDS   = tostring(data.vault_generic_secret.rds.data["password"])
  }))
}

# Auto Scaling Group for Frontend Template
module "carshub_frontend_asg" {
  source                    = "./modules/auto_scaling_group"
  name                      = "carshub_frontend_asg"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  target_group_arns         = [module.carshub_frontend_lb.target_groups[0].arn]
  vpc_zone_identifier       = module.carshub_public_subnets.subnets[*].id
  launch_template_id        = module.carshub_frontend_launch_template.id
  launch_template_version   = "$Latest"
}

# Auto Scaling Group for Backend Template
module "carshub_backend_asg" {
  source                    = "./modules/auto_scaling_group"
  name                      = "carshub_backend_asg"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  target_group_arns         = [module.carshub_backend_lb.target_groups[0].arn]
  vpc_zone_identifier       = module.carshub_public_subnets.subnets[*].id
  launch_template_id        = module.carshub_backend_launch_template.id
  launch_template_version   = "$Latest"
}

# Frontend Load Balancer
module "carshub_frontend_lb" {
  source                     = "./modules/load-balancer"
  lb_name                    = "carshub-frontend-lb"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = false
  security_groups            = [module.carshub_frontend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name      = "carshub-frontend-target-group"
      target_port            = 80
      target_ip_address_type = "ipv4"
      target_protocol        = "HTTP"
      target_type            = "instance"
      target_vpc_id          = module.carshub_vpc.vpc_id

      health_check_interval            = 30
      health_check_path                = "/auth/signin"
      health_check_enabled             = true
      health_check_protocol            = "HTTP"
      health_check_timeout             = 5
      health_check_healthy_threshold   = 3
      health_check_unhealthy_threshold = 3
      health_check_port                = 80
    }
  ]
  listeners = [
    {
      listener_port     = 80
      listener_protocol = "HTTP"
      default_actions = [
        {
          type             = "forward"
          target_group_arn = module.carshub_frontend_lb.target_groups[0].arn
        }
      ]
    }
  ]
}

# Backend Load Balancer
module "carshub_backend_lb" {
  source                     = "./modules/load-balancer"
  lb_name                    = "carshub-backend-lb"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = false
  security_groups            = [module.carshub_backend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name      = "carshub-backend-target-group"
      target_port            = 80
      target_ip_address_type = "ipv4"
      target_protocol        = "HTTP"
      target_type            = "instance"
      target_vpc_id          = module.carshub_vpc.vpc_id

      health_check_interval            = 30
      health_check_path                = "/"
      health_check_enabled             = true
      health_check_protocol            = "HTTP"
      health_check_timeout             = 5
      health_check_healthy_threshold   = 3
      health_check_unhealthy_threshold = 3
      health_check_port                = 80
    }
  ]
  listeners = [
    {
      listener_port     = 80
      listener_protocol = "HTTP"
      default_actions = [
        {
          type             = "forward"
          target_group_arn = module.carshub_backend_lb.target_groups[0].arn
        }
      ]
    }
  ]
}
