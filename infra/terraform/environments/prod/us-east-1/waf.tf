# -----------------------------------------------------------------------------------------
# WAF Configuration
# -----------------------------------------------------------------------------------------
module "carshub_waf" {
  source = "../../../modules/waf"

  # Naming convention
  name = "carshub-waf-${var.env}-${var.region}"

  # Attach WAF to the public-facing Frontend ALB
  frontend_alb_arn = module.carshub_frontend_lb.arn

  # Reuse SNS alarm topic
  alarm_topic_arn = module.carshub_alarm_notifications.topic_arn

  # Account + region for log resource policy
  account_id = data.aws_caller_identity.current.account_id
  aws_region = var.region

  # IP Management
  blocked_ip_list = []
  allowed_ip_list = []

  # Geo Blocking (empty = serve all traffic)
  blocked_countries = []

  # Rate Limiting
  rate_limit_requests      = 2000
  auth_rate_limit_requests = 100

  # Logging retention
  log_retention_days = 90

  # Alarm Thresholds
  alarm_blocked_requests_threshold = 500
  alarm_rate_limit_threshold       = 100
  alarm_auth_rate_limit_threshold  = 20

  tags = {
    Name        = "carshub-waf-${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}
