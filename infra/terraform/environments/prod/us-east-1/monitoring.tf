# -----------------------------------------------------------------------------------------
# CloudWatch Alarm Configuration
# -----------------------------------------------------------------------------------------
module "carshub_alarm_notifications" {
  source     = "../../../modules/sns"
  topic_name = "carshub-cloudwatch-alarm-notification-topic-${var.env}-${var.region}"
  subscriptions = [
    {
      protocol = "email"
      endpoint = var.alarm_email
    }
  ]
  tags = {
    Name        = "carshub-cloudwatch-alarm-notification-topic-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}

# Frontend ALB p95 Response Time Alarm
module "carshub_frontend_alb_high_response_time" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-frontend-alb-high-response-time-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  extended_statistic  = "p95"
  threshold           = "1" # 1 second response time
  alarm_description   = "This metric monitors frontend ALB target response time (p95)"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_frontend_lb.target_groups["carshub_frontend_lb_target_group"].arn_suffix
    LoadBalancer = module.carshub_frontend_lb.arn_suffix
  }
}

# Frontend ALB 5XX Error Rate Alarm
module "carshub_frontend_lb_high_5xx_errors" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-frontend-alb-high-5xx-errors-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors number of frontend 5XX errors"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_frontend_lb.target_groups["carshub_frontend_lb_target_group"].arn_suffix
    LoadBalancer = module.carshub_frontend_lb.arn_suffix
  }
}

# Backend ALB p95 Response Time Alarm
module "carshub_backend_lb_high_response_time" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-backend-alb-high-response-time-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  extended_statistic  = "p95"
  threshold           = "1" # 1 second response time
  alarm_description   = "This metric monitors backend ALB target response time (p95)"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_backend_lb.target_groups["carshub_backend_lb_target_group"].arn_suffix
    LoadBalancer = module.carshub_backend_lb.arn_suffix
  }
}

# Backend ALB 5XX Error Rate Alarm
module "carshub_backend_lb_high_5xx_errors" {
  source              = "../../../modules/cloudwatch/cloudwatch-alarm"
  alarm_name          = "carshub-backend-alb-high-5xx-errors-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors number of backend 5XX errors"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    TargetGroup  = module.carshub_backend_lb.target_groups["carshub_backend_lb_target_group"].arn_suffix
    LoadBalancer = module.carshub_backend_lb.arn_suffix
  }
}

# Lambda Error Rate Alarm
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

# SQS Queue Depth Alarm
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

# RDS High CPU Utilization Alarm
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
    DBInstanceIdentifier = module.carshub_db.id
  }
}

# RDS Low Storage Space Alarm
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
    DBInstanceIdentifier = module.carshub_db.id
  }
}

# RDS High Connections Alarm
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
  alarm_description   = "Alarm when RDS connections exceed threshold"
  alarm_actions       = [module.carshub_alarm_notifications.topic_arn]
  ok_actions          = [module.carshub_alarm_notifications.topic_arn]

  dimensions = {
    DBInstanceIdentifier = module.carshub_db.id
  }
}
