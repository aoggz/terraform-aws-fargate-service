# lb-fargate-service

Terraform module for a load balanced ECS Service using the Fargate launch type.

It will create the following:

- Application Load Balancer in the subnets you specify:
  - `alb_subnets_private` if `alb_internal = true`
  - `alb_subnets_public` if `alb_internal = false`
- ECS service
  - Belongs of the cluster specified by `ecs_cluster_id`
  - Creates tasks in the subnets specified in `alb_subnets_private`
  - According to the task definition & count that you specify
- IAM roles & policies
- Security groups

**Note**: The provisioning of the ECS task definition and ECR repository was extracted with version 3.\*. Use the [`web-fargate-app`](https://github.com/aoggz/terraform-aws-web-fargate-app) module for similar functionality as previous versions

## Usage

```hcl
module "cool-module-name-here" {
  source  = "aoggz/fargate-service/aws"
  version = "2.0.0"

  resource_prefix                           = local.resource_prefix
  ecs_cluster_id                            = var.ecs_cluster_id
  acm_certificate_domain                    = var.acm_certificate_domain
  log_retention_in_days                     = 30
  app_domain                                = var.app_domain              # must be a subdomain of the acm_certificate_domain
  route53_hosted_zone_id                    = var.hosted_zone_id          # Route 53 hosted zone id in which alias to load balancer
  task_count                                = var.app_instance_count      # Number of instances to run
  alb_internal                              = true
  alb_subnets_public                        = var.public_subnet_ids
  alb_subnets_private                       = var.private_subnet_ids
  alb_listener_default_action               = "redirect"                  # Note: if redirect is used, another lb_listener_rule must be created that forwards to the target group
  alb_listener_default_redirect_host        = var.redirect_host
  alb_listener_default_redirect_port        = "443"
  alb_listener_default_redirect_protocol    = "HTTPS"
  alb_listener_default_redirect_status_code = "HTTP_302"
  vpc_id                                    = var.vpc_id
}
```
