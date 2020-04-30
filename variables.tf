variable "resource_prefix" {
  type        = string
  description = "Naming prefix to use for resources to be provisioned"
}

variable "account_name" {
  type        = string
  description = "Name representing the current AWS account to be injected into web container environment variables"
  default     = "Unknown"
}

variable "acm_certificate_domain" {
  type        = string
  description = "The domain of the certificate to be registered with the ALB listener"
}

variable "ecs_cluster_id" {
  type = string
}

variable "ecs_cluster_name" {
  type        = string
  description = "Only needed if enable_monitoring = 1"
  default     = ""
}

variable "ecs_task_definition_arn" {
  type        = string
  description = "ARN of ECS task definition to use with service"
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "monitoring_evaluation_periods" {
  type        = number
  default     = 1
  description = "Number of periods to evaluate for the alarm"
}

variable "monitoring_slack_webhook_url" {
  type    = string
  default = ""
}

variable "monitoring_slack_channel" {
  type    = string
  default = ""
}

variable "monitoring_period" {
  type        = number
  default     = 300
  description = "Duration (in seconds) to evaluate for the alarm"
}

# variable "log_retention_in_days" {
#   type        = string
#   description = "Number of days CloudWatch logs for all ECS task containers should be retained."
#   default     = "30"
# }

variable "app_domain" {
  type        = string
  description = "The domain at which the application will be registered"
}

variable "route53_hosted_zone_id" {
  type        = string
  description = "The Hosted Zone ID at which the app_domain will be registered"
}

variable "task_count" {
  type    = string
  default = 1
}

variable "alb_internal" {
  type    = string
  default = 1
}

variable "alb_listener_default_action" {
  type        = string
  default     = "forward"
  description = "Only forward and redirect are currently supported"
}

variable "alb_allowed_ingress_cidr_blocks" {
  type        = list(string)
  default     = ["10.0.0.0/8"]
  description = "[Optional] CIDR block allowed to access load balancer. Defaults to 10.0.0.0/8."
}

variable "alb_default_target_group_arn" {
  type        = string
  default     = ""
  description = "[Optional] ARN of the default target group for the load balancer. Defaults to the target group created by this module."
}

variable "alb_subnets_private" {
  type        = list(string)
  description = "List of Ids of subnets in which load balancer will be hosted if alb_internal = true. App will be hosted in private subnets."
}

variable "alb_subnets_public" {
  type        = list(string)
  description = "List of Ids of subnets in which load balancer will be hosted if alb_internal = false"
}

variable "alb_listener_default_redirect_host" {
  type        = string
  description = "Host to which request will be redirected (only used if alb_listener_default_action is redirect)"
  default     = "#{host}"
}

variable "alb_listener_default_redirect_port" {
  type        = string
  description = "Port used when redirecting request from ALB (only used if alb_listener_default_action is redirect)"
  default     = "#{port}"
}

variable "alb_listener_default_redirect_path" {
  type        = string
  description = "Path to which request will be redirected (only used if alb_listener_default_action is redirect)"
  default     = "/#{path}"
}

variable "alb_listener_default_redirect_protocol" {
  type        = string
  description = "Protocol used when redirecting request from ALB (only used if alb_listener_default_action is redirect)"
  default     = "#{protocol}"
}

variable "alb_listener_default_redirect_query" {
  type        = string
  description = "The query parameters, URL-encoded when necessary, but not percent-encoded. Do not include the leading `?` (only used if alb_listener_default_action is redirect)"
  default     = "#{query}"
}

variable "alb_listener_default_redirect_status_code" {
  type        = string
  description = "Status code used when redirecting request from ALB (only used if alb_listener_default_action is redirect)"
  default     = "HTTP_301"
}

variable "vpc_id" {
  type        = string
  description = "ID of VPC in which all infrastucture will be provisioned"
}

variable "app_port" {
  type    = string
  default = 443
}

variable "app_healthcheck_endpoint" {
  type        = string
  default     = "/health-check"
  description = "[Optional] Endpoint that the Application Load Balancer will use to ensure a task is healthy. Defaults to /health-check"
}

variable "enable_autoscale" {
  type        = bool
  default     = false
  description = "[Optional] Autoscale - enables autoscaling for ecs tasks"
}

variable "task_max_instance_count" {
  type        = string
  default     = 2
  description = "[Optional] Autoscale - max task count used for autoscaling"
}

variable "task_scale_out_memory_threshold_percent" {
  type        = number
  default     = 50
  description = "[Optional] Autoscale - When average memory utilization % is greater than or equal to value increase tasks by 1"
}

variable "task_scale_out_cpu_threshold_percent" {
  type        = number
  default     = 60
  description = "[Optional] Autoscale - When average cpu utilization % is greater than or equal to value increase tasks by 1"
}

variable "task_scale_in_memory_threshold_percent" {
  type = number
  default = 25
  description= "[Optional] Autoscale - When both cpu and memory are below scale in thresholds decrease tasks by 1. Only applies when the total number of tasks exceed the minimum task count. number of running tasks determined by HealthyHostCount."
}

variable "task_scale_in_cpu_threshold_percent" {
  type        = number
  default     = 30
  description = "[Optional] Autoscale - When both cpu and memory are below scale in thresholds decrease tasks by 1. Only applies when the total number of tasks exceed the minimum task count. number of running tasks determined by HealthyHostCount."
}

variable "task_scale_in_cooldown_period" {
  type        = number
  default     = 300
  description = "[Optional] Autoscale - scale in cooldown period, in seconds"
}

variable "task_scale_out_cooldown_period" {
  type        = number
  default     = 300
  description = "[Optional] Autoscale - scale out cooldown period, in seconds"
}

variable "task_alarm_period" {
  type        = number
  default     = 60
  description = "[Optional] Autoscale - period of time to evaluate, in seconds"
}

variable "task_alarm_evaluation_periods" {
  type        = number
  default     = 3
  description = "[Optional] Autoscale - number of data points to use for evaluation"
}

variable "target_group_slow_start" {
  type        = number
  default     = 300
  description = "[Optional] Load balancer - time period to wait before forwarding requests to the target group, time in seconds."
}

variable "service_depends_on" {
  type        = any
  default     = null
  description = "[Optional] service - resources that the service depends on. Will delay deployment of service until resources available"
}