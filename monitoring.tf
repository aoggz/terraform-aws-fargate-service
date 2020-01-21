##################
## Resources    ##
##################

### Slack forwarder lambda

module "notify-slack" {
  source  = "terraform-aws-modules/notify-slack/aws"
  version = "~> 2.0"
  create  = var.enable_monitoring

  lambda_function_name = trim(substr("${var.resource_prefix}-${terraform.workspace}-cloudwatch-events-forwarder", 0, 64), "-") # 64 character max-length
  sns_topic_name       = "${var.resource_prefix}-${terraform.workspace}-cloudwatch-events"
  slack_webhook_url    = var.monitoring_slack_webhook_url
  slack_channel        = var.monitoring_slack_channel
  slack_username       = "Amazon CloudWatch"
}

### CloudWatch configuration

# module "alb-target-group-cloudwatch-sns-alarms" {
#   source  = "cloudposse/alb-target-group-cloudwatch-sns-alarms/aws"
#   version = "0.6.1"

#   enabled = var.enable_monitoring

#   namespace               = var.resource_prefix
#   stage                   = terraform.workspace
#   name                    = "alb-tg-alarms"
#   notify_arns             = [module.notify-slack.this_slack_topic_arn]
#   alb_name                = aws_lb.main.name
#   alb_arn_suffix          = aws_lb.main.arn_suffix
#   target_group_name       = aws_lb_target_group.app.name
#   target_group_arn_suffix = aws_lb_target_group.app.arn_suffix
#   treat_missing_data      = "notBreaching"
#   evaluation_periods      = "3"

#   target_3xx_count_threshold = "-1"
#   target_5xx_count_threshold = "5"
#   target_4xx_count_threshold = "5"
#   elb_5xx_count_threshold    = "5"
# }


resource "aws_cloudwatch_metric_alarm" "httpcode_target_5xx_count" {
  count                     = var.enable_monitoring ? 1 : 0
  alarm_name                = "${var.resource_prefix}-${terraform.workspace}-5XX-target-group-errors"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = var.monitoring_evaluation_periods
  metric_name               = "HTTPCode_Target_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = var.monitoring_period
  statistic                 = "Sum"
  threshold                 = 5
  treat_missing_data        = "notBreaching"
  alarm_description         = "${var.resource_prefix}-${terraform.workspace}-5XX-target-group-errors"
  alarm_actions             = [module.notify-slack.this_slack_topic_arn]
  ok_actions                = [module.notify-slack.this_slack_topic_arn]
  insufficient_data_actions = [module.notify-slack.this_slack_topic_arn]

  dimensions = {
    "TargetGroup"  = aws_lb_target_group.app.arn_suffix
    "LoadBalancer" = aws_lb.main.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_host_count" {
  count                     = var.enable_monitoring ? 1 : 0
  alarm_name                = "${var.resource_prefix}-${terraform.workspace}-unhealthy-hosts"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = var.monitoring_evaluation_periods
  metric_name               = "UnHealthyHostCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = var.monitoring_period
  statistic                 = "Average"
  threshold                 = 0
  alarm_description         = "${var.resource_prefix}-${terraform.workspace}-unhealthy-hosts"
  alarm_actions             = [module.notify-slack.this_slack_topic_arn]
  ok_actions                = [module.notify-slack.this_slack_topic_arn]
  insufficient_data_actions = [module.notify-slack.this_slack_topic_arn]

  dimensions = {
    "TargetGroup"  = aws_lb_target_group.app.arn_suffix
    "LoadBalancer" = aws_lb.main.arn_suffix
  }
}
