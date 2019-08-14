# lb-fargate-service

Terraform module for a load balanced ECS Service using the Fargate launch type.

It will create the following:

- Application Load Balancer in the subnets you specify:
  - `alb_subnets_private` if `alb_internal = true`
  - `alb_subnets_public` if `alb_internal = false`
- ECR Repositories for `web` and `reverse_proxy` images
- ECS Task Definition
  - `web` container using the definition you specify
  - [`nginx_reverse_proxy`](https://github.com/aoggz/nginx-reverse-proxy) container listening at port 443
    - Forwards request to port 127.0.0.1:80
  - [`xray`](https://hub.docker.com/r/amazon/aws-xray-daemon) container listening at port 2000
- ECS service
  - Belongs of the cluster specified by `ecs_cluster_id`
  - Creates tasks in the subnets specified in `alb_subnets_public`
- IAM roles & policies
- Security groups
- CloudWatch log group

## Usage

```hcl
module "cool-module-name-here" {
  source =  "aoggz/fargate-service/aws"

  resource_prefix                           = "${local.resource_prefix}"
  ecs_cluster_id                            = "${var.ecs_cluster_id}"
  acm_certificate_domain                    = "${var.acm_certificate_domain}"
  log_retention_in_days                     = 30
  app_domain                                = "${var.app_domain}"                   # must be a subdomain of the acm_certificate_domain
  route53_hosted_zone_id                    = "${var.hosted_zone_id}"               # Route 53 hosted zone id in which alias to load balancer
  task_count                                = "${var.app_instance_count}"           # Number of instances to run
  reverse_proxy_cpu                         = "${var.reverse_proxy_cpu}"            # Number of CPU Units for reverse_proxy container
  reverse_proxy_memory                      = "${var.reverse_proxy_memory}"         # MB of RAM for reverse_proxy container
  reverse_proxy_version                     = "1.0.0"                               # Docker image tag of nginx_reverse_proxy container
  reverse_proxy_cert_state                  = "PA"
  reverse_proxy_cert_locality               = "Pittsburgh"
  reverse_proxy_cert_organization           = "Awesome"
  reverse_proxy_cert_organizational_unit    = "Sauce"
  reverse_proxy_cert_email_address          = "awesome@sau.ce"
  xray_cpu                                  = "${var.xray_cpu}"                     # Number of CPU Units for xray container
  xray_memory                               = "${var.xray_memory}"                  # MB of RAM for xray container
  web_cpu                                   = "${var.web_cpu}"                      # Number of CPU Units for web container
  web_memory                                = "${var.web_memory}"                   # MB of RAM for web container
  web_image                                 = "${var.web_image}"                    # Name of Docker image to use for web container
  web_version                               = "${var.web_version}"                  # Version of Docker image to use for web container
  web_container_definition                  = "${module.web.container_definitions}" # JSON ECS Task definition for web container
  alb_internal                              = true
  alb_subnets_public                        = ["${var.public_subnet_ids)}"]
  alb_subnets_private                       = ["${var.private_subnet_ids)}"]
  alb_listener_default_action               = "redirect"
  alb_listener_default_redirect_host        = "${var.redirect_host}"
  alb_listener_default_redirect_port        = "443"
  alb_listener_default_redirect_protocol    = "HTTPS"
  alb_listener_default_redirect_status_code = "HTTP_302"
  vpc_id                                    = "${var.vpc_id}"
}

module "web" {
  source = "mongodb/ecs-task-definition/aws"

  name                     = "web"
  family                   = "web"
  cpu                      = "${var.web_cpu}"
  image                    = "${module.mud.web_ecr_repository_url}:${var.web_version}"
  memory                   = "${var.web_memory}"
  essential                = true
  register_task_definition = false

  # hostPort mapping is not supported in the lb-fargate-service module. This container will be exposed via the reverse_proxy container.
  portMappings = [
    {
      containerPort = 80
    },
  ]

  logConfiguration {
    logDriver = "awslogs"

    options {
      awslogs-region        = "us-east-1"
      awslogs-group         = "${module.mud.cloudwatch_log_group_name}"
      awslogs-stream-prefix = "web"
    }
  }

  environment = [
    {
      name  = "ASPNETCORE_ENVIRONMENT"
      value = "Development"
    },
  ]
}
```

https://www.terraform.io/docs/modules/sources.html
