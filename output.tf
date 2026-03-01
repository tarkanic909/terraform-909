output "node_info" {
  value = {
    for node_name in keys(var.nodes) :
    node_name => {
      name   = node_name
      ip     = "192.168.100.${10 + index(keys(var.nodes), node_name)}"
      memory = var.nodes[node_name].memory
      vcpu   = var.nodes[node_name].vcpu
    }
  }
}