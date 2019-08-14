locals {
  # Had to do it a complicated way: https://github.com/hashicorp/terraform/issues/18259#issuecomment-438407005
  alb_subnets      = "${split(",", var.alb_internal == "1" ? join(",", var.alb_subnets_private) : join(",", var.alb_subnets_public))}"
  datadog_cpu      = "${var.datadog_enabled == "1" ? var.datadog_cpu : "0"}"
  datadog_memory   = "${var.datadog_enabled == "1" ? var.datadog_memory : "0"}"
  alb_listener_arn = "${var.alb_listener_default_action == "forward" ? aws_lb_listener.front_end_forward.0.arn : aws_lb_listener.front_end_redirect.0.arn}"
}
