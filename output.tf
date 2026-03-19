output "node_info" {
  value = {
    for node_name, node in var.nodes :
    node_name => {
      name            = node_name
      mgmt_ip         = local.mgmt_ips[node_name]
      lan_ip          = split("/", node.lan_cidr)[0]
      lan_cidr        = node.lan_cidr
      lan_network     = cidrhost(node.lan_cidr, 0)
      interlink_ip    = try(local.interlink_ips[node_name], null)
      memory          = node.memory
      vcpu            = node.vcpu
      role            = node.role
      bgp_as          = node.bgp_as
      bgp_neighbor_ip = node.role == "router" ? try(local.interlink_ips[local.interlink_neighbors[node_name]], null) : null
      bgp_neighbor_as = node.role == "router" ? try(var.nodes[local.interlink_neighbors[node_name]].bgp_as, null) : null
    }
  }
}
