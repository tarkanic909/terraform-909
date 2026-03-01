output "node_info" {
  value = {
    for node_name in keys(var.nodes) :
    node_name => {
      name   = node_name
      ip     = local.mgmt_ips[node_name]
      memory = var.nodes[node_name].memory
      vcpu   = var.nodes[node_name].vcpu
    }
  }
}
