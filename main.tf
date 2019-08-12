resource "aws_ecr_repository" "web" {
  name = "${var.resource_prefix}-${terraform.workspace}/web"
}

resource "aws_ecr_repository" "reverse_proxy" {
  name = "${var.resource_prefix}-${terraform.workspace}/reverse_proxy"
}

resource "aws_security_group" "lb" {
  # count = "${var.alb_enabled}"

  name        = "${var.resource_prefix}-lb-${terraform.workspace}"
  description = "LB for ${var.resource_prefix} - ${terraform.workspace}"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "${var.resource_prefix}-lb-${terraform.workspace}"
  }
}

resource "aws_security_group_rule" "lb_ingress" {
  # count = "${var.alb_enabled}"

  security_group_id = "${aws_security_group.lb.id}"
  type              = "ingress"
  protocol          = "TCP"
  from_port         = "${var.app_port}"
  to_port           = "${var.app_port}"
  cidr_blocks       = ["${var.alb_allowed_ingress_cidr_blocks}"]
}

# Need to leave it open to allow it to talk to Cognito (for authentication) & ECS control plane
resource "aws_security_group_rule" "lb_egress" {
  # count = "${var.alb_enabled}"

  security_group_id        = "${aws_security_group.lb.id}"
  type                     = "egress"
  protocol                 = "TCP"
  from_port                = "${var.app_port}"
  to_port                  = "${var.app_port}"
  source_security_group_id = "${aws_security_group.ecs_task.id}"
}

resource "aws_lb" "main" {
  # count = "${var.alb_enabled}"

  name               = "${replace("${var.resource_prefix}-${terraform.workspace}", "/(.{0,32})(.*)/", "$1")}" # 32 character max-length
  load_balancer_type = "application"
  internal           = "${var.alb_internal == "1"}"

  subnets         = ["${local.alb_subnets}"]
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_lb_target_group" "app" {
  # count = "${var.alb_enabled}"

  name        = "${replace("${var.resource_prefix}-${terraform.workspace}", "/(.{0,32})(.*)/", "$1")}" # 32 character max-length
  port        = "${var.app_port}"
  protocol    = "HTTPS"
  vpc_id      = "${var.vpc_id}"
  target_type = "ip"

  health_check {
    path     = "${var.app_healthcheck_endpoint}"
    protocol = "HTTPS"
    interval = 60
  }
}

resource "aws_lb_listener" "front_end" {
  # count = "${var.alb_enabled}"

  load_balancer_arn = "${aws_lb.main.id}"
  port              = "${var.app_port}"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.main.arn}"

  default_action {
    target_group_arn = "${var.alb_default_target_group_arn == "" ? aws_lb_target_group.app.id : var.alb_default_target_group_arn}"
    type             = "forward"
  }
}

resource "aws_route53_record" "www" {
  zone_id = "${var.route53_hosted_zone_id}"
  name    = "${var.app_domain}"
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.main.dns_name}"
    zone_id                = "${aws_lb.main.zone_id}"
    evaluate_target_health = true
  }
}

resource "null_resource" "publish_web_docker_image" {
  provisioner "local-exec" {
    command = <<EOF
$(aws ecr get-login --no-include-email --region us-east-1) && \
docker tag $LOCAL_TAG $TAG && \
docker push $TAG
EOF

    environment {
      TAG       = "${aws_ecr_repository.web.repository_url}:${var.web_version}"
      LOCAL_TAG = "${var.web_image}:${var.web_version}"
    }
  }

  triggers {
    value = "${var.web_image}:${var.web_version}"
  }

  depends_on = ["aws_ecr_repository.web"]
}

resource "aws_ecs_service" "main" {
  name            = "${var.resource_prefix}-${terraform.workspace}"
  cluster         = "${var.ecs_cluster_id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = "${var.task_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.ecs_task.id}"]
    subnets         = ["${var.alb_subnets_private}"]
  }

  # load_balancer {
  #   target_group_arn = "${aws_lb_target_group.app.id}"
  #   container_name   = "reverse_proxy"
  #   container_port   = "${var.app_port}"
  # }

  # depends_on = [
  #   "aws_lb_listener.front_end",
  # ]
}

resource "aws_security_group" "ecs_task" {
  name        = "${var.resource_prefix}-${terraform.workspace}-common-ecstask"
  description = "${var.resource_prefix} ECS Tasks"
  vpc_id      = "${var.vpc_id}"

  tags {
    Name = "${var.resource_prefix}-${terraform.workspace}-common-ecstask"
  }
}

resource "aws_security_group_rule" "ecs_task_ingress" {
  security_group_id = "${aws_security_group.ecs_task.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.app_port}"
  to_port           = "${var.app_port}"

  # source_security_group_id = "${aws_security_group.lb.id}"
  cidr_blocks = ["0.0.0.0/0"]
}

# Need to leave it open to allow it to talk to Cognito (for authentication) & ECS control plane
resource "aws_security_group_rule" "ecs_task_egress" {
  security_group_id = "${aws_security_group.ecs_task.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

module "xray" {
  source = "mongodb/ecs-task-definition/aws"

  name                     = "xray"
  family                   = "web"
  cpu                      = "${var.xray_cpu}"
  image                    = "amazon/aws-xray-daemon"
  memory                   = "${var.xray_memory}"
  essential                = false
  register_task_definition = false

  portMappings = [
    {
      containerPort = 2000
      hostPort      = 2000
      protocol      = "udp"
    },
  ]

  logConfiguration {
    logDriver = "awslogs"

    options {
      awslogs-region        = "${data.aws_region.current.name}"
      awslogs-group         = "${aws_cloudwatch_log_group.main.name}"
      awslogs-stream-prefix = "xray"
    }
  }
}

module "reverse_proxy" {
  source = "mongodb/ecs-task-definition/aws"

  name                     = "${local.proxy_container_name}"
  family                   = "web"
  cpu                      = "${var.reverse_proxy_cpu}"
  image                    = "111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:${var.reverse_proxy_version}"
  memory                   = "${var.reverse_proxy_memory}"
  essential                = true
  register_task_definition = false
  user                     = "1337"

  ulimits = [
    {
      name      = "nofile"
      hardLimit = "15000"
      softLimit = "15000"
    },
  ]

  portMappings = [
    {
      containerPort = "${var.app_port}"
      hostPort      = "${var.app_port}"
    },
    {
      containerPort = 9901
      hostPort      = 9901
      protocol      = "tcp"
    },
    {
      containerPort = 15000
      hostPort      = 15000
      protocol      = "tcp"
    },
    {
      containerPort = 15001
      hostPort      = 15001
      protocol      = "tcp"
    },
  ]

  logConfiguration {
    logDriver = "awslogs"

    options {
      awslogs-region        = "${data.aws_region.current.name}"
      awslogs-group         = "${aws_cloudwatch_log_group.main.name}"
      awslogs-stream-prefix = "reverse_proxy"
    }
  }

  healthCheck {
    interval = 5
    timeout  = 2
    retries  = 3

    command = [
      "CMD-SHELL",
      "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE",
    ]
  }

  environment = [
    {
      name  = "APPMESH_VIRTUAL_NODE_NAME"
      value = "mesh/zoll-wcd-web-external/virtualNode/${aws_appmesh_virtual_node.node.name}"
    },
    {
      name  = "ENVOY_LOG_LEVEL"
      value = "debug"
    },
    {
      name  = "ENABLE_ENVOY_XRAY_TRACING"
      value = "1"
    },
    {
      name  = "ENABLE_ENVOY_STATS_TAGS"
      value = "1"
    },
  ]
}

module "merged" {
  source = "mongodb/ecs-task-definition/aws//modules/merge"

  container_definitions = [
    "${var.web_container_definition}",
    "${module.xray.container_definitions}",
    "${module.reverse_proxy.container_definitions}",
  ]
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.resource_prefix}-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.xray_cpu + var.web_cpu + var.reverse_proxy_cpu}"
  memory                   = "${var.xray_memory + var.web_memory + var.reverse_proxy_memory}"
  container_definitions    = "${module.merged.container_definitions}"
  execution_role_arn       = "${aws_iam_role.execution.arn}"
  task_role_arn            = "${aws_iam_role.task.arn}"

  proxy_configuration {
    type           = "APPMESH"
    container_name = "${local.proxy_container_name}"

    properties = {
      AppPorts           = "${var.app_port}"
      EgressIgnoredIPs   = "169.254.170.2,169.254.169.254"
      EgressIgnoredPorts = "1433"
      IgnoredUID         = "1337"
      ProxyEgressPort    = 15001
      ProxyIngressPort   = 15000
    }
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "${var.resource_prefix}-${terraform.workspace}"
  retention_in_days = "${var.log_retention_in_days}"

  # tags              = "${local.tags}"
}

resource "aws_iam_role_policy" "task" {
  name   = "${var.resource_prefix}-${terraform.workspace}-task"
  role   = "${aws_iam_role.task.id}"
  policy = "${data.aws_iam_policy_document.task_permissions.json}"
}

resource "aws_iam_role" "task" {
  name               = "${var.resource_prefix}-${terraform.workspace}-task"
  assume_role_policy = "${data.aws_iam_policy_document.task_execution.json}"
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.main.arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
  }
}

data "aws_iam_policy_document" "task_execution" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${replace("${var.resource_prefix}-${terraform.workspace}-task-exec", "/(.{0,64})(.*)/", "$1")}" # 64 character max-length
  assume_role_policy = "${data.aws_iam_policy_document.task_execution.json}"
}

resource "aws_iam_role_policy" "task_execution" {
  name   = "${var.resource_prefix}-${terraform.workspace}-task-exec"
  role   = "${aws_iam_role.execution.id}"
  policy = "${data.aws_iam_policy_document.task_execution_permissions.json}"
}

data "aws_iam_policy_document" "task_execution_permissions" {
  statement {
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}
