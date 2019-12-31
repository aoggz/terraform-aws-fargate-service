locals {
  # Had to do it a complicated way: https://github.com/hashicorp/terraform/issues/18259#issuecomment-438407005
  alb_subnets = var.alb_internal ? var.alb_subnets_private : var.alb_subnets_public
}
