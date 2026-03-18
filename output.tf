output "node_info" {
  value = {
    for node_name, node in var.nodes :
    node_name => {
      name            = node_name
      mgmt_ip         = local.mgmt_ips[node_name]
      lan_ip          = node.lan_ip
      lan_network     = node.lan_network
      interlink_ip    = try(local.interlink_ips[node_name], null)
      memory          = node.memory
      vcpu            = node.vcpu
      role            = node.role
      bgp_as          = node.bgp_as
      bgp_neighbor_ip = try(local.interlink_ips[local.interlink_neighbors[node_name]], null)
      bgp_neighbor_as = try(var.nodes[local.interlink_neighbors[node_name]].bgp_as, null)
    }
  }
}
