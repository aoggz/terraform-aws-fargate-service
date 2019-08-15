locals {
  # Had to do it a complicated way: https://github.com/hashicorp/terraform/issues/18259#issuecomment-438407005
  alb_subnets = split(
    ",",
    var.alb_internal == "1" ? join(",", var.alb_subnets_private) : join(",", var.alb_subnets_public),
  )
  proxy_container_name  = "reverse_proxy"
  service_dns           = "${var.resource_prefix}.${terraform.workspace}.local"
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
      "name": "${local.proxy_container_name}",
      "family": "web",
      "cpu": ${var.reverse_proxy_cpu},
      "image": "111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:${var.reverse_proxy_version}",
      "memory": ${var.reverse_proxy_memory},
      "essential": true,
      "user": 1337,
      "ulimits": [
        {
          "name": "nofile",
          "hardLimit": 15000,
          "softLimit": 15000
        }
      ]
      "portMappings": [
        {
          "containerPort": ${var.app_port},
          "hostPort": ${var.app_port},
          "protocol": "tcp"
        },
        {
          "containerPort": 9901,
          "hostPort": 9901,
          "protocol": "tcp"
        },
        {
          "containerPort": 15000,
          "hostPort": 15000,
          "protocol": "tcp"
        },
        {
          "containerPort": 15001,
          "hostPort": 15001,
          "protocol": "tcp"
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
      "healthCheck": {
        "interval": 5,
        "timeout": 2,
        "retries": 3,
        "command": [
          "CMD-SHELL",
          "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
        ]
      }
      "environment": [
        {
          "name": "APPMESH_VIRTUAL_NODE_NAME",
          "value": "mesh/${var.app_mesh_name}/virtualNode/${aws_appmesh_virtual_node.node.name}"
        },
        {
          "name": "ENVOY_LOG_LEVEL",
          "value": "debug"
        },
        {
          "name": "ENABLE_ENVOY_XRAY_TRACING",
          "value": "1"
        },
        {
          "name": "ENABLE_ENVOY_STATS_TAGS",
          "value": "1"
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
