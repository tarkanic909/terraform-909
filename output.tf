output "node_info" {
  value = {
    for node_name in keys(var.nodes) :
    node_name => {
      name            = node_name
      mgmt_ip         = local.mgmt_ips[node_name]
      lan_ip          = var.nodes[node_name].lan_ip
      interlink_ip    = lookup(local.interlink_ips, node_name, "")
      memory          = var.nodes[node_name].memory
      vcpu            = var.nodes[node_name].vcpu
      role            = var.nodes[node_name].role
      as              = var.nodes[node_name].as
      bgp_neighbor_ip = lookup(local.interlink_ips, lookup(local.interlink_neighbors, node_name, ""), "")
      bgp_neighbor_as = try(var.nodes[local.interlink_neighbors[node_name]].as, 0)
    }
  }
}
