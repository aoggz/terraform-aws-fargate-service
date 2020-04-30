
resource "aws_security_group" "lb" {
  name        = "${var.resource_prefix}-lb-${terraform.workspace}"
  description = "LB for ${var.resource_prefix} - ${terraform.workspace}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.resource_prefix}-lb-${terraform.workspace}"
  }
}

resource "aws_security_group_rule" "lb_ingress" {
  security_group_id = aws_security_group.lb.id
  type              = "ingress"
  protocol          = "TCP"
  from_port         = var.app_port
  to_port           = var.app_port
  cidr_blocks       = var.alb_allowed_ingress_cidr_blocks
}

# Need to leave it open to allow it to talk to Cognito (for authentication) & ECS control plane
resource "aws_security_group_rule" "lb_egress" {
  security_group_id        = aws_security_group.lb.id
  type                     = "egress"
  protocol                 = "TCP"
  from_port                = var.app_port
  to_port                  = var.app_port
  source_security_group_id = aws_security_group.ecs_task.id
}

resource "aws_lb" "main" {
  name               = trim(substr("${var.resource_prefix}-${terraform.workspace}", 0, 32), "-") # 32 character max-length
  load_balancer_type = "application"
  internal           = var.alb_internal
  subnets            = local.alb_subnets
  security_groups    = [aws_security_group.lb.id]
  depends_on         = [var.service_depends_on]
}

resource "aws_lb_target_group" "app" {
  name        = trim(substr("${var.resource_prefix}-${terraform.workspace}", 0, 32), "-") # 32 character max-length
  port        = var.app_port
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "ip"
  slow_start  = var.target_group_slow_start

  health_check {
    path     = var.app_healthcheck_endpoint
    protocol = "HTTPS"
    interval = 60
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.id
  port              = var.app_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.main.arn

  dynamic "default_action" {
    for_each = var.alb_listener_default_action == "forward" ? [{}] : []
    content {
      target_group_arn = var.alb_default_target_group_arn == "" ? aws_lb_target_group.app.id : var.alb_default_target_group_arn
      type             = "forward"
    }
  }

  dynamic "default_action" {
    for_each = var.alb_listener_default_action == "redirect" ? [{}] : []
    content {
      type = "redirect"

      redirect {
        host        = var.alb_listener_default_redirect_host
        port        = var.alb_listener_default_redirect_port
        path        = var.alb_listener_default_redirect_path
        protocol    = var.alb_listener_default_redirect_protocol
        query       = var.alb_listener_default_redirect_query
        status_code = var.alb_listener_default_redirect_status_code
      }
    }
  }
}

resource "aws_route53_record" "www" {
  zone_id = var.route53_hosted_zone_id
  name    = var.app_domain
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.main.dns_name}"
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_ecs_service" "main" {
  name            = "${var.resource_prefix}-${terraform.workspace}"
  cluster         = var.ecs_cluster_id
  task_definition = var.ecs_task_definition_arn
  desired_count   = var.task_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_task.id]
    subnets         = var.alb_subnets_private
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.id
    container_name   = "reverse_proxy"
    container_port   = var.app_port
  }

  depends_on = [
    aws_lb_listener.front_end,
  ]
}

resource "aws_security_group" "ecs_task" {
  name        = "${var.resource_prefix}-${terraform.workspace}-common-ecstask"
  description = "${var.resource_prefix} ECS Tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.resource_prefix}-${terraform.workspace}-common-ecstask"
  }
}

resource "aws_security_group_rule" "ecs_task_ingress" {
  security_group_id        = aws_security_group.ecs_task.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.app_port
  to_port                  = var.app_port
  source_security_group_id = aws_security_group.lb.id
}

# Need to leave it open to allow it to talk to Cognito (for authentication) & ECS control plane
resource "aws_security_group_rule" "ecs_task_egress" {
  security_group_id = aws_security_group.ecs_task.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
