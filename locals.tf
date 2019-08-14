locals {
  # Had to do it a complicated way: https://github.com/hashicorp/terraform/issues/18259#issuecomment-438407005
  alb_subnets = split(
    ",",
    var.alb_internal == "1" ? join(",", var.alb_subnets_private) : join(",", var.alb_subnets_public),
  )
  container_definitions = <<-EOT
  [
    {
      "name": "xray",
      "family": "web",
      "cpu": ${var.xray_cpu},
      "image": "amazon/aws-xray-daemon",
      "memory": ${var.xray_memory},
      "essential": false,
      "portMappings": [
        {
          "containerPort": 2000,
          "protocol": "udp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
          "awslogs-stream-prefix": "xray"
        }
      }
    },
    {
      "name": "reverse_proxy",
      "family": "web",
      "cpu": ${var.reverse_proxy_cpu},
      "image": "aoggz/nginx-reverse-proxy:${var.reverse_proxy_version}",
      "memory": ${var.reverse_proxy_memory},
      "essential": true,
      "portMappings": [
        {
          "containerPort": ${var.app_port},
          "hostPort": ${var.app_port}
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
          "awslogs-stream-prefix": "reverse_proxy"
        }
      },
      "environment": [
        {
          "name": "DOMAIN",
          "value": "${var.app_domain}"
        },
        {
          "name": "PROXY_ADDRESS",
          "value": "127.0.0.1"
        },
        {
          "name": "COUNTRY",
          "value": "${var.reverse_proxy_cert_country}"
        },
        {
          "name": "STATE",
          "value": "${var.reverse_proxy_cert_state}"
        },
        {
          "name": "LOCALITY",
          "value": "${var.reverse_proxy_cert_locality}"
        },
        {
          "name": "ORGANIZATION",
          "value": "${var.reverse_proxy_cert_organization}"
        },
        {
          "name": "ORGANIZATIONAL_UNIT",
          "value": "${var.reverse_proxy_cert_organizational_unit}"
        },
        {
          "name": "EMAIL_ADDRESS",
          "value": "${var.reverse_proxy_cert_email_address}"
        }
      ]
    },
    {
      "name": "web",
      "family": "web",
      "cpu": ${var.web_cpu},
      "image": "${aws_ecr_repository.web.repository_url}:${var.web_version}",
      "memory": ${var.web_memory},
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
          "awslogs-stream-prefix": "web"
        }
      },
      "environment": [
        %{for env_var in var.web_environment_variables}
        {
          "name": "${lookup(env_var, "name", "UNKNOWN")}",
          "value": "${lookup(env_var, "value", "UNKNOWN")}"
        },
        %{endfor}
        {
          "name": "STAGE",
          "value": "${terraform.workspace}"
        },
        {
          "name": "AWS__Region",
          "value": "${data.aws_region.current.name}"
        },
        {
          "name": "Environment__AccountName",
          "value": "${var.account_name}"
        },
        {
          "name": "Environment__Stage",
          "value": "${terraform.workspace}"
        },
        {
          "name": "Environment__Version",
          "value": "${var.web_version}"
        },
        {
          "name": "Environment__IsLocal",
          "value": "false"
        },
        {
          "name": "AWS_XRAY_DAEMON_ADDRESS",
          "value": ""
        }
      ]
    }
  ]
  EOT
}
