# Registering vault provider
data "vault_generic_secret" "rds" {
  path = "secret/rds"
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------------------

module "carshub_vpc" {
  source                = "../../../modules/vpc/vpc"
  vpc_name              = "carshub-vpc-${var.env}-${var.region}"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "carshub-vpc-igw-${var.env}-${var.region}"
}

# Security Group
module "carshub_frontend_lb_sg" {
  source = "../../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub-frontend-lb-sg-${var.env}-${var.region}"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTP traffic"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
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
  source = "../../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub-backend-lb-sg-${var.env}-${var.region}"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
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
  source = "../../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub-asg-frontend-sg-${var.env}-${var.region}"
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
  source = "../../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub-asg-backend-sg-${var.env}-${var.region}"
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
  source = "../../../modules/vpc/security_groups"
  vpc_id = module.carshub_vpc.vpc_id
  name   = "carshub-rds-sg-${var.env}-${var.region}"
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
  source = "../../../modules/vpc/subnets"
  name   = "carshub-public-subnet-${var.env}-${var.region}"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.carshub_vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "carshub_private_subnets" {
  source = "../../../modules/vpc/subnets"
  name   = "carshub-private-subnet-${var.env}-${var.region}"
  subnets = [
    {
      subnet = "10.0.4.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.6.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.carshub_vpc.vpc_id
  map_public_ip_on_launch = false
}

# Carshub Public Route Table
module "carshub_public_rt" {
  source  = "../../../modules/vpc/route_tables"
  name    = "carshub-public-route-table-${var.env}-${var.region}"
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

resource "aws_eip" "carshub_nat_eip" {
  count  = length(module.carshub_public_subnets.subnets)
  domain = "vpc"

  tags = {
    Name = "carshub-nat-eip-${count.index + 1}"
  }
}

# NAT Gateways (one per AZ)
resource "aws_nat_gateway" "carshub_vpc_nat" {
  count = length(module.carshub_public_subnets.subnets)

  allocation_id = aws_eip.carshub_nat_eip[count.index].id
  subnet_id     = module.carshub_public_subnets.subnets[count.index].id

  tags = {
    Name = "carshub-nat-gateway-${count.index + 1}-${var.env}-${var.region}"
  }
}

resource "aws_route_table" "carshub_private_rt" {
  count  = length(aws_nat_gateway.carshub_vpc_nat)
  vpc_id = module.carshub_vpc.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.carshub_vpc_nat[count.index].id
  }

  tags = {
    Name = "carshub-private-route-table-${count.index + 1}-${var.env}-${var.region}"
  }
}

resource "aws_route_table_association" "carshub_private_rt_association" {
  count          = length(module.carshub_private_subnets.subnets)
  subnet_id      = module.carshub_private_subnets.subnets[count.index].id
  route_table_id = aws_route_table.carshub_private_rt[count.index].id
}

# -----------------------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------------------
module "carshub_db_credentials" {
  source                  = "../../../modules/secrets-manager"
  name                    = "carshub-rds-secrets-${var.env}-${var.region}"
  description             = "carshub-rds-secrets-${var.env}-${var.region}"
  recovery_window_in_days = 0
  secret_string = jsonencode({
    username = tostring(data.vault_generic_secret.rds.data["username"])
    password = tostring(data.vault_generic_secret.rds.data["password"])
  })
}

# -----------------------------------------------------------------------------------------
# VPC Flow Logs
# -----------------------------------------------------------------------------------------

# IAM Role for VPC Flow Logs
module "flow_logs_role" {
  source             = "../../../modules/iam"
  role_name          = "carshub-flow-logs-role-${var.env}-${var.region}"
  role_description   = "carshub-flow-logs-role-${var.env}-${var.region}"
  policy_name        = "carshub-flow-logs-policy-${var.env}-${var.region}"
  policy_description = "carshub-flow-logs-policy-${var.env}-${var.region}"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "vpc-flow-logs.amazonaws.com"
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
                  "logs:PutLogEvents",
                  "logs:DescribeLogGroups",
                  "logs:DescribeLogStreams"
                ],
                "Resource": "*",
                "Effect": "Allow"
            }
        ]
    }
    EOF
}

resource "aws_cloudwatch_log_group" "carshub_flow_log_group" {
  name              = "/carshub/application/${var.env}-${var.region}"
  retention_in_days = 365
}

# Add VPC Flow Logs for security monitoring
resource "aws_flow_log" "carshub_vpc_flow_log" {
  iam_role_arn    = module.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.carshub_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = module.carshub_vpc.vpc_id
}

# -----------------------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------------------

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "carshub-rds-monitoring-role-${var.env}-${var.region}"

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
  source                          = "../../../modules/rds"
  db_name                         = "carshubdb${var.env}useast1"
  allocated_storage               = 100
  storage_type                    = "gp3"
  engine                          = "mysql"
  engine_version                  = "8.0.40"
  instance_class                  = "db.r6g.large"
  multi_az                        = true
  username                        = tostring(data.vault_generic_secret.rds.data["username"])
  password                        = tostring(data.vault_generic_secret.rds.data["password"])
  subnet_group_name               = "carshub-rds-subnet-group-${var.env}-${var.region}"
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
  deletion_protection                   = false
  skip_final_snapshot                   = true
  max_allocated_storage                 = 500
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring_role.arn
  parameter_group_name                  = "carshub-db-pg-${var.env}-${var.region}"
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
  source      = "../../../modules/s3"
  bucket_name = "carshub-media-bucket${var.env}-${var.region}"
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
  # Note: Lifecycle policies should be configured in the S3 module
  # or as separate aws_s3_bucket_lifecycle_configuration resources
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
  source      = "../../../modules/s3"
  bucket_name = "carshub-media-updatefunctioncode${var.env}-${var.region}"
  objects = [
    {
      key    = "lambda.zip"
      source = "../../../files/lambda.zip"
    }
  ]
  bucket_policy = ""
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
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
  source             = "../../../modules/s3"
  bucket_name        = "carshub-media-update-function-code-signed${var.env}-${var.region}"
  versioning_enabled = "Enabled"
  force_destroy      = true
  bucket_policy      = ""
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
}

# Signing profile
module "carshub_signing_profile" {
  source                           = "../../../modules/signing-profile"
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
  source                        = "../../../modules/sqs"
  queue_name                    = "carshub-media-events-queue-${var.env}-${var.region}"
  delay_seconds                 = 0
  maxReceiveCount               = 3
  dlq_message_retention_seconds = 86400
  dlq_name                      = "carshub-media-events-dlq-${var.env}-${var.region}"
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
        Resource  = "arn:aws:sqs:${var.region}:*:carshub-media-events-queue-${var.env}-${var.region}"
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
  source             = "../../../modules/iam"
  role_name          = "carshub-media-update-function-iam-role-${var.env}-${var.region}"
  role_description   = "carshub-media-update-function-iam-role-${var.env}-${var.region}"
  policy_name        = "carshub-media-update-function-iam-policy-${var.env}-${var.region}"
  policy_description = "carshub-media-update-function-iam-policy-${var.env}-${var.region}"
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
  filename            = "../../../files/python.zip"
  layer_name          = "python"
  compatible_runtimes = ["python3.12"]
}

# Lambda function to update media metadata in RDS database
module "carshub_media_update_function" {
  source        = "../../../modules/lambda"
  function_name = "carshub-media-update-${var.env}-${var.region}"
  role_arn      = module.carshub_media_update_function_iam_role.arn
  permissions   = []
  env_variables = {
    SECRET_NAME = module.carshub_db_credentials.name
    DB_HOST     = tostring(split(":", module.carshub_db.endpoint)[0])
    DB_NAME     = var.db_name
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
  source                                = "../../../modules/cloudfront"
  distribution_name                     = "carshub-media-cdn-${var.env}-${var.region}"
  oac_name                              = "carshub-media-cdn-oac-${var.env}-${var.region}"
  oac_description                       = "carshub-media-cdn-oac-${var.env}-${var.region}"
  oac_origin_access_control_origin_type = "s3"
  oac_signing_behavior                  = "always"
  oac_signing_protocol                  = "sigv4"
  enabled                               = true
  origin = [
    {
      origin_id           = "carshub-media-bucket-${var.env}"
      domain_name         = "carshub-media-bucket-${var.env}.s3.${var.region}.amazonaws.com"
      connection_attempts = 3
      connection_timeout  = 10
    }
  ]
  compress                       = true
  smooth_streaming               = false
  target_origin_id               = "carshub-media-bucket-${var.env}"
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

# -----------------------------------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------------------------------

module "iam_instance_profile_role" {
  source             = "../../../modules/iam"
  role_name          = "iam-instance-profile-role-${var.env}-${var.region}"
  role_description   = "iam-instance-profile-role-${var.env}-${var.region}"
  policy_name        = "iam-instance-profile-policy-${var.env}-${var.region}"
  policy_description = "iam-instance-profile-policy-${var.env}-${var.region}"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "ec2.amazonaws.com"
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
                  "s3:*"
                ],
                "Resource": "*",
                "Effect": "Allow"
            }
        ]
    }
    EOF
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = module.iam_instance_profile_role.name
}

# Carshub frontend instance template
module "carshub_frontend_launch_template" {
  source                               = "../../../modules/launch_template"
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
  user_data = base64encode(templatefile("${path.module}/../../../scripts/user_data_frontend.sh", {
    BASE_URL = "http://${module.carshub_backend_lb.lb_dns_name}"
    CDN_URL  = module.carshub_media_cloudfront_distribution.domain_name
  }))
}

# Carshub backend instance template
module "carshub_backend_launch_template" {
  source                               = "../../../modules/launch_template"
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
  user_data = base64encode(templatefile("${path.module}/../../../scripts/user_data_backend.sh", {
    DB_PATH = tostring(split(":", module.carshub_db.endpoint)[0])
    UN      = tostring(data.vault_generic_secret.rds.data["username"])
    CREDS   = tostring(data.vault_generic_secret.rds.data["password"])
    DB_NAME = module.carshub_db.name
  }))
}

# Auto Scaling Group for Frontend Template
module "carshub_frontend_asg" {
  source                    = "../../../modules/auto_scaling_group"
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
  source                    = "../../../modules/auto_scaling_group"
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
  source                     = "../../../modules/load-balancer"
  lb_name                    = "carshub-frontend-lb-${var.env}"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = true
  security_groups            = [module.carshub_frontend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name                = "carshub-frontend-tg-${var.env}"
      target_port                      = 80
      target_ip_address_type           = "ipv4"
      target_protocol                  = "HTTP"
      target_type                      = "instance"
      target_vpc_id                    = module.carshub_vpc.vpc_id
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
  source                     = "../../../modules/load-balancer"
  lb_name                    = "carshub-backend-lb-${var.env}"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  enable_deletion_protection = true
  security_groups            = [module.carshub_backend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name                = "carshub-backend-tg-${var.env}"
      target_port                      = 80
      target_ip_address_type           = "ipv4"
      target_protocol                  = "HTTP"
      target_type                      = "instance"
      target_vpc_id                    = module.carshub_vpc.vpc_id
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
# Cloudwath Alarm Configuration
# -----------------------------------------------------------------------------------------

module "carshub_alarm_notifications" {
  source     = "../../../modules/sns"
  topic_name = "carshub_cloudwatch_alarm_notification_topic"
  subscriptions = [
    {
      protocol = "email"
      endpoint = "madmaxcloudonline@gmail.com"
    }
  ]
}

# Target Response Time Alarm (if using ALB)
module "carshub_frontend_alb_high_response_time" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "${module.carshub_frontend_lb.arn}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  extended_statistic  = "p95"
  threshold           = "1" # 1 second response time
  alarm_description   = "This metric monitors ALB target response time (p95)"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_frontend_lb.target_groups[0].arn
    LoadBalancer = "${module.carshub_frontend_lb.arn}"
  }
}

# HTTP 5XX Error Rate Alarm (if using ALB)
module "carshub_frontend_lb_high_5xx_errors" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "${module.carshub_frontend_lb.arn}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10" # Adjust based on your traffic pattern
  alarm_description   = "This metric monitors number of 5XX errors"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_frontend_lb.target_groups[0].arn
    LoadBalancer = "${module.carshub_frontend_lb.arn}"
  }
}

# # -------------------------------------------------------------------------------------------------------------------------

# Target Response Time Alarm (if using ALB)
module "carshub_backend_lb_high_response_time" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "${module.carshub_backend_lb.arn}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  extended_statistic  = "p95"
  statistic           = "Average"
  threshold           = "1" # 1 second response time
  alarm_description   = "This metric monitors ALB target response time (p95)"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_backend_lb.target_groups[0].arn
    LoadBalancer = "${module.carshub_backend_lb.arn}"
  }
}

# HTTP 5XX Error Rate Alarm (if using ALB)
module "carshub_backend_lb_high_5xx_errors" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "${module.carshub_backend_lb.arn}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10" # Adjust based on your traffic pattern
  alarm_description   = "This metric monitors number of 5XX errors"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_backend_lb.target_groups[0].arn
    LoadBalancer = "${module.carshub_backend_lb.arn}"
  }
}

module "lambda_errors" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-media-update-lambda-errors-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when Lambda function errors > 0 in 5 minutes"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    FunctionName = module.carshub_media_update_function.function_name
  }
}

module "sqs_queue_depth" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-media-events-queue-depth-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Alarm when SQS queue depth > 100"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    QueueName = module.carshub_media_events_queue.name
  }
}

module "rds_high_cpu" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-rds-high-cpu-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when RDS CPU utilization > 80% for 10 minutes"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]
  dimensions = {
    DBInstanceIdentifier = module.carshub_db.name
  }
}

module "rds_low_storage" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-rds-low-storage-${var.env}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "Alarm when RDS free storage < 10 GB"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]
  dimensions = {
    DBInstanceIdentifier = module.carshub_db.name
  }
}

module "rds_high_connections" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-rds-high-connections-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Alarm when RDS connections exceed 80% of max"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]
  dimensions = {
    DBInstanceIdentifier = module.carshub_db.name
  }
}