# resource "aws_appmesh_mesh" "mesh" {
#   name = "${var.resource_prefix}-mesh"

#   spec {
#     egress_filter {
#       type = "ALLOW_ALL"
#     }
#   }
# }

# resource "aws_appmesh_virtual_router" "router" {
#   name      = "${var.resource_prefix}"
#   mesh_name = "${aws_appmesh_mesh.mesh.id}"

#   spec {
#     listener {
#       port_mapping {
#         port     = "${var.app_port}"
#         protocol = "http"
#       }
#     }
#   }
# }

resource "aws_appmesh_virtual_node" "node" {
  name      = "${var.resource_prefix}"
  mesh_name = "zoll-wcd-web-external"  #"${aws_appmesh_mesh.mesh.id}"

  spec {
    backend {
      virtual_service {
        virtual_service_name = "${local.service_dns}"
      }
    }

    listener {
      port_mapping {
        port     = "${var.app_port}"
        protocol = "http"
      }
    }

    service_discovery {
      dns {
        hostname = "${local.service_dns}"
      }
    }
  }
}

# resource "aws_appmesh_route" "route" {
#   name                = "${var.resource_prefix}"
#   mesh_name           = "zoll-wcd-web-external"                     #"${aws_appmesh_mesh.mesh.id}"
#   virtual_router_name = "${aws_appmesh_virtual_router.router.name}"


#   spec {
#     http_route {
#       match {
#         prefix = "/"
#       }


#       action {
#         weighted_target {
#           virtual_node = "${aws_appmesh_virtual_node.node.name}"
#           weight       = 100
#         }
#       }
#     }
#   }
# }

