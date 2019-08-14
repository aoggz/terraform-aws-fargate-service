locals {
  # Had to do it a complicated way: https://github.com/hashicorp/terraform/issues/18259#issuecomment-438407005
  alb_subnets = "${split(",", var.alb_internal == "1" ? join(",", var.alb_subnets_private) : join(",", var.alb_subnets_public))}"
}
