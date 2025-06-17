# Registering vault provider
data "vault_generic_secret" "rds" {
  path = "secret/rds"
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------------------

module "carshub_vpc" {
  source                = "../../modules/vpc/vpc"
  vpc_name              = "carshub_vpc_${var.env}"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "carshub_vpc_igw_${var.env}"
}

# Security Group
module "carshub_frontend_lb_sg" {
  source = "../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_frontend_lb_sg_${var.env}"
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
  source = "../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_backend_lb_sg_${var.env}"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      # security_groups = [module.carshub_frontend_lb_sg.id]
      description = "any"
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
  source = "../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_asg_frontend_sg_${var.env}"
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
  source = "../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_asg_backend_sg_${var.env}"
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
  source = "../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub_rds_sg_${var.env}"
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
  source = "../../modules/vpc/subnets"
  name   = "carshub public subnet_${var.env}"
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
  source = "../../modules/vpc/subnets"
  name   = "carshub private subnet_${var.env}"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "us-east-1a"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "us-east-1c"
    }
  ]
  vpc_id                  = module.carshub_vpc.vpc_id
  map_public_ip_on_launch = false
}

# Carshub Public Route Table
module "carshub_public_rt" {
  source  = "../../modules/vpc/route_tables"
  name    = "carshub public route table_${var.env}"
  subnets = module.carshub_public_subnets.subnets[*]
  routes = [
    {
      cidr_block     = "0.0.0.0/0"
      gateway_id     = module.carshub_vpc.igw_id
      nat_gateway_id = ""
    }
  ]
  vpc_id = module.carshub_vpc.vpc_id
}

# Carshub Private Route Table
module "carshub_private_rt" {
  source  = "../../modules/vpc/route_tables"
  name    = "carshub private route table_${var.env}"
  subnets = module.carshub_private_subnets.subnets[*]
  routes = [
    {
      cidr_block     = module.carshub_public_subnets.subnets[0].cidr_block
      nat_gateway_id = module.carshub_nat.nat[0].id
      gateway_id     = ""
    },
    {
      cidr_block     = module.carshub_public_subnets.subnets[1].cidr_block
      nat_gateway_id = module.carshub_nat.nat[1].id
      gateway_id     = ""
    },
    {
      cidr_block     = module.carshub_public_subnets.subnets[2].cidr_block
      nat_gateway_id = module.carshub_nat.nat[2].id
      gateway_id     = ""
    }
  ]
  vpc_id = module.carshub_vpc.vpc_id
}

# Nat Gateway
module "carshub_nat" {
  source      = "../../modules/vpc/nat"
  subnets     = module.carshub_public_subnets.subnets[*]
  eip_name    = "carshub_vpc_nat_eip"
  nat_gw_name = "carshub_vpc_nat"
  domain      = "vpc"
}

# -----------------------------------------------------------------------------------------
# VPC Flow Logs
# -----------------------------------------------------------------------------------------

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs_role" {
  name = "flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for the Flow Logs Role
resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "carshub_flow_log_group" {
  name              = "/carshub/application/${var.env}"
  retention_in_days = 365
}

# Add VPC Flow Logs for security monitoring
resource "aws_flow_log" "carshub_vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.carshub_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = module.carshub_vpc.vpc_id
}

# -----------------------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------------------

module "carshub_db_credentials" {
  source                  = "../../modules/secrets-manager"
  name                    = "carshub_rds_secrets_${var.env}"
  description             = "carshub_rds_secrets_${var.env}"
  recovery_window_in_days = 0
  secret_string = jsonencode({
    username = tostring(data.vault_generic_secret.rds.data["username"])
    password = tostring(data.vault_generic_secret.rds.data["password"])
  })
}

# -----------------------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------------------

## IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

module "carshub_db" {
  source                          = "../../modules/rds"
  db_name                         = "carshub_${var.env}"
  allocated_storage               = 100
  engine                          = "mysql"
  engine_version                  = "8.0"
  instance_class                  = "db.t4g.large"
  multi_az                        = true
  username                        = tostring(data.vault_generic_secret.rds.data["username"])
  password                        = tostring(data.vault_generic_secret.rds.data["password"])
  subnet_group_name               = "carshub_rds_subnet_group"
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  backup_retention_period         = 35
  backup_window                   = "03:00-06:00"
  subnet_group_ids = [
    module.carshub_private_subnets.subnets[0].id,
    module.carshub_private_subnets.subnets[1].id,
    module.carshub_private_subnets.subnets[2].id
  ]
  vpc_security_group_ids                = [module.carshub_rds_sg.id]
  publicly_accessible                   = false
  deletion_protection                   = true
  skip_final_snapshot                   = false
  max_allocated_storage                 = 500
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring_role.arn
  parameter_group_name                  = "carshub-db-pg-${var.env}"
  parameter_group_family                = "mysql8.0"
  parameters = [
    {
      name  = "max_connections"
      value = "1000"
    },
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    },
    {
      name  = "slow_query_log"
      value = "1"
    }
  ]
}

# -----------------------------------------------------------------------------------------
# S3 Configuration
# -----------------------------------------------------------------------------------------

module "carshub_media_bucket" {
  source      = "../../modules/s3"
  bucket_name = "carshubmediabucket${var.env}"
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
      allowed_headers = ["${module.carshub_media_cloudfront_distribution.domain_name}"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    },
    {
      allowed_headers = ["${module.carshub_frontend_lb.lb_dns_name}"]
      allowed_methods = ["PUT"]
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
    lambda_function = []
  }
}

module "carshub_media_update_function_code" {
  source      = "../../modules/s3"
  bucket_name = "carshubmediaupdatefunctioncode${var.env}"
  objects = [
    {
      key    = "lambda.zip"
      source = "../../files/lambda.zip"
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

# -----------------------------------------------------------------------------------------
# Signing Profile
# -----------------------------------------------------------------------------------------

module "carshub_media_update_function_code_signed" {
  source             = "../../modules/s3"
  bucket_name        = "carshubmediaupdatefunctioncodesigned${var.env}"
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

# Signing profile
module "carshub_signing_profile" {
  source                           = "../../modules/signing-profile"
  platform_id                      = "AWSLambda-SHA384-ECDSA"
  signature_validity_value         = 5
  signature_validity_type          = "YEARS"
  ignore_signing_job_failure       = true
  untrusted_artifact_on_deployment = "Warn"
  s3_bucket_key                    = "lambda.zip"
  s3_bucket_source                 = module.carshub_media_update_function_code.bucket
  s3_bucket_version                = module.carshub_media_update_function_code.objects[0].version_id
  s3_bucket_destination            = module.carshub_media_update_function_code_signed.bucket
}

# -----------------------------------------------------------------------------------------
# SQS Config
# -----------------------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "sqs_event_trigger" {
  event_source_arn                   = module.carshub_media_events_queue.arn
  function_name                      = module.carshub_media_update_function.arn
  enabled                            = true
  batch_size                         = 10
  maximum_batching_window_in_seconds = 60
}

# SQS Queue for buffering S3 events
module "carshub_media_events_queue" {
  source                        = "../../modules/sqs"
  queue_name                    = "carshub-media-events-queue-${var.env}"
  delay_seconds                 = 0
  maxReceiveCount               = 3
  dlq_message_retention_seconds = 86400
  dlq_name                      = "carshub-media-events-dlq-${var.env}"
  max_message_size              = 262144
  message_retention_seconds     = 345600
  visibility_timeout_seconds    = 180
  receive_wait_time_seconds     = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = "arn:aws:sqs:us-east-1:*:carshub-media-events-queue-${var.env}"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.carshub_media_bucket.arn
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------------------
# Lambda Config
# -----------------------------------------------------------------------------------------

# Lambda IAM  Role
module "carshub_media_update_function_iam_role" {
  source             = "../../modules/iam"
  role_name          = "carshub_media_update_function_iam_role_${var.env}"
  role_description   = "carshub_media_update_function_iam_role_${var.env}"
  policy_name        = "carshub_media_update_function_iam_policy_${var.env}"
  policy_description = "carshub_media_update_function_iam_policy_${var.env}"
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
                "Action": ["s3:GetObject", "s3:PutObject"],
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

# Lambda Layer for storing dependencies
resource "aws_lambda_layer_version" "python_layer" {
  filename            = "../../files/python.zip"
  layer_name          = "python"
  compatible_runtimes = ["python3.12"]
}

# Lambda function to update media metadata in RDS database
module "carshub_media_update_function" {
  source        = "../../modules/lambda"
  function_name = "carshub_media_update_${var.env}"
  role_arn      = module.carshub_media_update_function_iam_role.arn
  permissions   = []
  env_variables = {
    SECRET_NAME = module.carshub_db_credentials.name
    DB_HOST     = tostring(split(":", module.carshub_db.endpoint)[0])
    DB_NAME     = "${module.carshub_db.name}"
    REGION      = var.region
  }
  handler                 = "lambda.lambda_handler"
  runtime                 = "python3.12"
  s3_bucket               = module.carshub_media_update_function_code.bucket
  s3_key                  = "lambda.zip"
  layers                  = [aws_lambda_layer_version.python_layer.arn]
  code_signing_config_arn = module.carshub_signing_profile.config_arn
}

# -----------------------------------------------------------------------------------------
# Cloudfront distribution
# -----------------------------------------------------------------------------------------

module "carshub_media_cloudfront_distribution" {
  source                                = "../../modules/cloudfront"
  distribution_name                     = "carshub_media_cdn_${var.env}"
  oac_name                              = "carshub_media_cdn_oac_${var.env}"
  oac_description                       = "carshub_media_cdn_oac_${var.env}"
  oac_origin_access_control_origin_type = "s3"
  oac_signing_behavior                  = "always"
  oac_signing_protocol                  = "sigv4"
  enabled                               = true
  origin = [
    {
      origin_id           = "carshubmediabucket_${var.env}"
      domain_name         = "carshubmediabucket_${var.env}.s3.${var.region}.amazonaws.com"
      connection_attempts = 3
      connection_timeout  = 10
    }
  ]
  compress                       = true
  smooth_streaming               = false
  target_origin_id               = "carshubmediabucket_${var.env}"
  allowed_methods                = ["GET", "HEAD"]
  cached_methods                 = ["GET", "HEAD"]
  viewer_protocol_policy         = "redirect-to-https"
  min_ttl                        = 0
  default_ttl                    = 86400
  max_ttl                        = 31536000
  price_class                    = "PriceClass_100"
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
  source                               = "../../modules/launch_template"
  name                                 = "carshub_frontend_launch_template_${var.env}"
  description                          = "carshub_frontend_launch_template_${var.env}"
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
  user_data = base64encode(templatefile("${path.module}/../../scripts/user_data_frontend.sh", {
    BASE_URL = "http://${module.carshub_backend_lb.lb_dns_name}"
    CDN_URL  = module.carshub_media_cloudfront_distribution.domain_name
  }))
}

# Carshub backend instance template
module "carshub_backend_launch_template" {
  source                               = "../../modules/launch_template"
  name                                 = "carshub_backend_launch_template_${var.env}"
  description                          = "carshub_backend_launch_template_${var.env}"
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
  user_data = base64encode(templatefile("${path.module}/../../scripts/user_data_backend.sh", {
    DB_PATH = tostring(split(":", module.carshub_db.endpoint)[0])
    UN      = tostring(data.vault_generic_secret.rds.data["username"])
    CREDS   = tostring(data.vault_generic_secret.rds.data["password"])
    DB_NAME = module.carshub_db.name
  }))
}

# Auto Scaling Group for Frontend Template
module "carshub_frontend_asg" {
  source                    = "../../modules/auto_scaling_group"
  name                      = "carshub_frontend_asg_${var.env}"
  min_size                  = 3
  max_size                  = 50
  desired_capacity          = 3
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  target_group_arns         = [module.carshub_frontend_lb.target_groups[0].arn]
  vpc_zone_identifier       = module.carshub_private_subnets.subnets[*].id
  launch_template_id        = module.carshub_frontend_launch_template.id
  launch_template_version   = "$Latest"
}

# Auto Scaling Group for Backend Template
module "carshub_backend_asg" {
  source                    = "../../modules/auto_scaling_group"
  name                      = "carshub_backend_asg_${var.env}"
  min_size                  = 3
  max_size                  = 50
  desired_capacity          = 3
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  target_group_arns         = [module.carshub_backend_lb.target_groups[0].arn]
  vpc_zone_identifier       = module.carshub_private_subnets.subnets[*].id
  launch_template_id        = module.carshub_backend_launch_template.id
  launch_template_version   = "$Latest"
}

# Frontend Load Balancer
module "carshub_frontend_lb" {
  source                     = "../../modules/load-balancer"
  lb_name                    = "carshub-frontend-lb-${var.env}"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = true
  security_groups            = [module.carshub_frontend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name      = "carshub-frontend-tg-${var.env}"
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
  source                     = "../../modules/load-balancer"
  lb_name                    = "carshub-backend-lb-${var.env}"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = true
  security_groups            = [module.carshub_backend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name      = "carshub-backend-tg-${var.env}"
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

# -----------------------------------------------------------------------------------------
# CodeBuild Configuration
# -----------------------------------------------------------------------------------------

# CodeBuild IAM Role
# data "aws_iam_policy_document" "codebuild_assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["codebuild.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "carshub_codebuild_iam_role" {
#   name               = "carshub-codebuild-iam-role-${var.env}"
#   assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
# }

# data "aws_iam_policy_document" "codebuild_cache_bucket_policy_document" {
#   statement {
#     effect = "Allow"

#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#     ]

#     resources = ["*"]
#   }

#   statement {
#     effect    = "Allow"
#     actions   = ["s3:*"]
#     resources = ["*"]
#   }

#   statement {
#     effect    = "Allow"
#     actions   = ["ecr:GetAuthorizationToken"]
#     resources = ["*"]
#   }

#   statement {
#     effect = "Allow"
#     actions = [
#       "ecr:BatchGetImage",
#       "ecr:BatchCheckLayerAvailability",
#       "ecr:CompleteLayerUpload",
#       "ecr:DescribeImages",
#       "ecr:DescribeRepositories",
#       "ecr:GetDownloadUrlForLayer",
#       "ecr:InitiateLayerUpload",
#       "ecr:ListImages",
#       "ecr:PutImage",
#       "ecr:UploadLayerPart"
#     ]
#     # resources = [module.carshub_frontend_container_registry.arn, module.carshub_backend_container_registry.arn]
#   }
# }

# resource "aws_iam_role_policy" "carshub_codebuild_cache_bucket_policy" {
#   role   = aws_iam_role.carshub_codebuild_iam_role.name
#   policy = data.aws_iam_policy_document.codebuild_cache_bucket_policy_document.json
# }

# module "carshub_codebuild_frontend" {
#   source                        = "../../modules/devops/codebuild"
#   build_timeout                 = 60
#   cache_bucket_name             = "carshubcodebuildfrontendcache${var.env}"
#   cloudwatch_group_name         = "carshub-codebuiild-frontend-group-${var.env}"
#   cloudwatch_stream_name        = "carshub-codebuiild-frontend-stream-${var.env}"
#   codebuild_project_description = "carshub-codebuild-frontend-${var.env}"
#   codebuild_project_name        = "carshub-codebuild-frontend-${var.env}"
#   role                          = aws_iam_role.carshub_codebuild_iam_role.arn
#   compute_type                  = "BUILD_GENERAL1_SMALL"
#   env_image                     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
#   env_type                      = "LINUX_CONTAINER"
#   fetch_submodules              = true
#   force_destroy_cache_bucket    = false
#   image_pull_credentials_type   = "CODEBUILD"
#   privileged_mode               = true
#   source_location               = "https://github.com/mmdcloud/aws-carshub-rest-vm.git"
#   source_git_clone_depth        = "1"
#   source_type                   = "GITHUB"
#   source_version                = "frontend"
#   environment_variables = [
#     {
#       name  = "ACCOUNT_ID"
#       value = data.aws_caller_identity.current.account_id
#     },
#     {
#       name  = "REGION"
#       value = "${var.region}"
#     },
#     {
#       name  = "REPO"
#       value = "carshub_frontend_${var.env}"
#     }
#   ]
# }

# module "carshub_codebuild_backend" {
#   source                        = "../../modules/devops/codebuild"
#   build_timeout                 = 60
#   cache_bucket_name             = "carshubcodebuildbackendcache${var.env}"
#   cloudwatch_group_name         = "carshub-codebuiild-backend-group-${var.env}"
#   cloudwatch_stream_name        = "carshub-codebuiild-backend-stream-${var.env}"
#   codebuild_project_description = "carshub-codebuild-backend-${var.env}"
#   codebuild_project_name        = "carshub-codebuild-backend-${var.env}"
#   role                          = aws_iam_role.carshub_codebuild_iam_role.arn
#   compute_type                  = "BUILD_GENERAL1_SMALL"
#   env_image                     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
#   env_type                      = "LINUX_CONTAINER"
#   fetch_submodules              = true
#   force_destroy_cache_bucket    = false
#   image_pull_credentials_type   = "CODEBUILD"
#   privileged_mode               = true
#   source_location               = "https://github.com/mmdcloud/aws-carshub-rest-vm.git"
#   source_git_clone_depth        = "1"
#   source_type                   = "GITHUB"
#   source_version                = "backend"
#   environment_variables = [
#     {
#       name  = "ACCOUNT_ID"
#       value = data.aws_caller_identity.current.account_id
#     },
#     {
#       name  = "REGION"
#       value = "${var.region}"
#     },
#     {
#       name  = "REPO"
#       value = "carshub_backend_${var.env}"
#     }
#   ]
# }

# # -----------------------------------------------------------------------------------------
# # CodeDeploy Configuration
# # -----------------------------------------------------------------------------------------

# data "aws_iam_policy_document" "codedeploy_assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["codedeploy.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "carshub_codedeploy_role" {
#   name               = "carshub-codedeploy-role"
#   assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
#   role       = aws_iam_role.carshub_codedeploy_role.name
# }


# # -----------------------------------------------------------------------------------------
# # CodePipeline Configuration
# # -----------------------------------------------------------------------------------------

# resource "aws_s3_bucket" "carshub_frontend_codepipeline_bucket" {
#   bucket        = "carshub-frontend-codepipeline-bucket-${var.env}"
#   force_destroy = false
# }

# resource "aws_s3_bucket_public_access_block" "carshub_frontend_codepipeline_bucket_pab" {
#   bucket = aws_s3_bucket.carshub_frontend_codepipeline_bucket.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # CodePipeline backend artifact bucket
# resource "aws_s3_bucket" "carshub_backend_codepipeline_bucket" {
#   bucket        = "carshub-backend-codepipeline-bucket-${var.env}"
#   force_destroy = false
# }

# resource "aws_s3_bucket_public_access_block" "carshub_backend_codepipeline_bucket_pab" {
#   bucket = aws_s3_bucket.carshub_backend_codepipeline_bucket.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # CodePipleine IAM Role
# resource "aws_codestarconnections_connection" "carshub_codepipeline_codestar_connection" {
#   name          = "carshub-codestar-connection"
#   provider_type = "GitHub"
# }

# data "aws_iam_policy_document" "carshub_codepipeline_assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["codepipeline.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "carshub_codepipeline_role" {
#   name               = "carshub-codepipeline-role-${var.env}"
#   assume_role_policy = data.aws_iam_policy_document.carshub_codepipeline_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "codepipeline_ecs_full_access" {
#   role       = aws_iam_role.carshub_codepipeline_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
# }

# data "aws_iam_policy_document" "codepipeline_policy" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "s3:GetObject",
#       "s3:GetObjectVersion",
#       "s3:GetBucketVersioning",
#       "s3:PutObjectAcl",
#       "s3:PutObject",
#     ]
#     resources = [
#       aws_s3_bucket.carshub_frontend_codepipeline_bucket.arn,
#       "${aws_s3_bucket.carshub_frontend_codepipeline_bucket.arn}/*",
#       aws_s3_bucket.carshub_backend_codepipeline_bucket.arn,
#       "${aws_s3_bucket.carshub_backend_codepipeline_bucket.arn}/*"
#     ]
#   }

#   statement {
#     effect = "Allow"
#     actions = [
#       "codedeploy:GetDeploymentConfig",
#     ]
#     resources = [
#       "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime"
#     ]
#   }

#   statement {
#     effect    = "Allow"
#     actions   = ["codestar-connections:UseConnection"]
#     resources = [aws_codestarconnections_connection.carshub_codepipeline_codestar_connection.arn]
#   }

#   statement {
#     effect = "Allow"
#     actions = [
#       "codebuild:BatchGetBuilds",
#       "codebuild:StartBuild",
#     ]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_role_policy" "codepipeline_policy" {
#   name   = "carshub-codepipeline-policy-${var.env}"
#   role   = aws_iam_role.carshub_codepipeline_role.id
#   policy = data.aws_iam_policy_document.codepipeline_policy.json
# }

# # CodePipeline for Frontend
# module "carshub_frontend_codepipeline" {
#   source              = "../../modules/devops/codepipeline"
#   name                = "carshub-frontend-codepipeline-${var.env}"
#   role_arn            = aws_iam_role.carshub_codepipeline_role.arn
#   artifact_bucket     = aws_s3_bucket.carshub_frontend_codepipeline_bucket.bucket
#   artifact_store_type = "S3"
#   stages = [
#     {
#       name = "Source"
#       actions = [
#         {
#           name             = "Source"
#           category         = "Source"
#           owner            = "AWS"
#           provider         = "CodeStarSourceConnection"
#           version          = "1"
#           action_type_id   = "Source"
#           run_order        = 1
#           input_artifacts  = []
#           output_artifacts = ["source_output"]
#           configuration = {
#             FullRepositoryId = "mmdcloud/aws-carshub-rest-vm"
#             BranchName       = "frontend"
#             ConnectionArn    = aws_codestarconnections_connection.carshub_codepipeline_codestar_connection.arn
#           }
#         }
#       ]
#     },
#     {
#       name = "Build"
#       actions = [
#         {
#           name             = "Build"
#           category         = "Build"
#           owner            = "AWS"
#           provider         = "CodeBuild"
#           version          = "1"
#           action_type_id   = "Build"
#           run_order        = 1
#           input_artifacts  = ["source_output"]
#           output_artifacts = ["build_output"]
#           configuration = {
#             ProjectName   = module.carshub_codebuild_frontend.project_name
#             PrimarySource = "source_output"
#             # EnvironmentVariables = jsonencode(module.carshub_codebuild_frontend.environment_variables)
#           }
#         }
#       ]
#     },
#     {
#       name = "Approval"
#       actions = [{
#         name             = "ManualApproval"
#         category         = "Approval"
#         owner            = "AWS"
#         provider         = "Manual"
#         input_artifacts  = []
#         output_artifacts = []
#         version          = "1"
#         configuration = {
#           NotificationArn = module.carshub_alarm_notifications.topic_arn
#           CustomData      = "Approve production deployment"
#         }
#       }]
#     },
#     {
#       name = "Deploy"
#       actions = [
#         {
#           name             = "DeployToECS"
#           category         = "Deploy"
#           owner            = "AWS"
#           provider         = "ECS"
#           version          = "1"
#           action_type_id   = "DeployToECS"
#           run_order        = 1
#           input_artifacts  = ["build_output"]
#           output_artifacts = []
#           configuration = {
#             ClusterName = aws_ecs_cluster.carshub_cluster.name
#             ServiceName = module.carshub_frontend_ecs.name
#             FileName    = "imagedefinitions.json"
#           }
#         }
#       ]
#     }
#   ]
# }

# # CodePipeline for Backend
# module "carshub_backend_codepipeline" {
#   source              = "../../modules/devops/codepipeline"
#   name                = "carshub-backend-codepipeline-${var.env}"
#   role_arn            = aws_iam_role.carshub_codepipeline_role.arn
#   artifact_bucket     = aws_s3_bucket.carshub_backend_codepipeline_bucket.bucket
#   artifact_store_type = "S3"
#   stages = [
#     {
#       name = "Source"
#       actions = [
#         {
#           name             = "Source"
#           category         = "Source"
#           owner            = "AWS"
#           provider         = "CodeStarSourceConnection"
#           version          = "1"
#           action_type_id   = "Source"
#           run_order        = 1
#           input_artifacts  = []
#           output_artifacts = ["source_output"]
#           configuration = {
#             FullRepositoryId = "mmdcloud/aws-carshub-rest-vm"
#             BranchName       = "backend"
#             ConnectionArn    = aws_codestarconnections_connection.carshub_codepipeline_codestar_connection.arn
#           }
#         }
#       ]
#     },
#     {
#       name = "Build"
#       actions = [
#         {
#           name             = "Build"
#           category         = "Build"
#           owner            = "AWS"
#           provider         = "CodeBuild"
#           version          = "1"
#           action_type_id   = "Build"
#           run_order        = 1
#           input_artifacts  = ["source_output"]
#           output_artifacts = ["build_output"]
#           configuration = {
#             ProjectName   = module.carshub_codebuild_backend.project_name
#             PrimarySource = "source_output"
#             # EnvironmentVariables = jsonencode(module.carshub_codebuild_frontend.environment_variables)
#           }
#         }
#       ]
#     },
#     {
#       name = "Approval"
#       actions = [{
#         name             = "ManualApproval"
#         category         = "Approval"
#         owner            = "AWS"
#         provider         = "Manual"
#         version          = "1"
#         input_artifacts  = []
#         output_artifacts = []
#         configuration = {
#           NotificationArn = module.carshub_alarm_notifications.topic_arn
#           CustomData      = "Approve production deployment"
#         }
#       }]
#     },
#     {
#       name = "Deploy"
#       actions = [
#         {
#           name             = "DeployToECS"
#           category         = "Deploy"
#           owner            = "AWS"
#           provider         = "ECS"
#           version          = "1"
#           action_type_id   = "DeployToECS"
#           run_order        = 1
#           input_artifacts  = ["build_output"]
#           output_artifacts = []
#           configuration = {
#             ClusterName = aws_ecs_cluster.carshub_cluster.name
#             ServiceName = module.carshub_backend_ecs.name
#             FileName    = "imagedefinitions.json"
#           }
#         }
#       ]
#     }
#   ]
# }