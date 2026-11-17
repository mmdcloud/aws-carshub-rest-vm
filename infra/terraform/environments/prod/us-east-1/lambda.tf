# -----------------------------------------------------------------------------------------
# Lambda Configuration
# -----------------------------------------------------------------------------------------
module "carshub_media_update_function_iam_role" {
  source             = "../../../modules/iam"
  role_name          = "carshub-media-update-function-iam-role-${var.env}-${var.region}"
  role_description   = "IAM role for media metadata update lambda function"
  policy_name        = "carshub-media-update-function-iam-policy-${var.env}-${var.region}"
  policy_description = "IAM policy for media metadata update lambda function"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
        Effect   = "Allow"
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:carshub-rds-secrets-${var.env}-${var.region}-*"
      },
      {
        Action   = ["s3:GetObject", "s3:PutObject"]
        Effect   = "Allow"
        Resource = "${module.carshub_media_bucket.arn}/*"
      },
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = module.carshub_media_events_queue.arn
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = module.carshub_media_events_dlq.arn
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
  tags = {
    Name        = "carshub-media-update-function-iam-role-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}

# Lambda Layer for storing dependencies
resource "aws_lambda_layer_version" "python_layer" {
  filename            = "${path.module}/../../../files/python.zip"
  layer_name          = "python"
  compatible_runtimes = ["python3.12"]
}

# Lambda function to update media metadata in RDS database
module "carshub_media_update_function" {
  source        = "../../../modules/lambda"
  function_name = "carshub-media-update-${var.env}-${var.region}"
  role_arn      = module.carshub_media_update_function_iam_role.arn
  permissions   = []
  vpc_config = {
    security_group_ids = [module.carshub_lambda_sg.id]
    subnet_ids         = module.carshub_vpc.private_subnets
  }
  dead_letter_config = {
    target_arn = module.carshub_media_events_dlq.arn
  }
  env_variables = {
    SECRET_NAME = module.carshub_db_credentials.name
    DB_HOST     = tostring(split(":", module.carshub_db.endpoint)[0])
    DB_NAME     = var.db_name
    REGION      = var.region
  }
  handler                 = "lambda.lambda_handler"
  runtime                 = "python3.12"
  s3_bucket               = module.carshub_media_update_function_code_signed.bucket
  s3_key                  = module.carshub_signing_profile.signed_object_key
  layers                  = [aws_lambda_layer_version.python_layer.arn]
  code_signing_config_arn = module.carshub_signing_profile.config_arn
  tags = {
    Name        = "carshub-media-update-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}
