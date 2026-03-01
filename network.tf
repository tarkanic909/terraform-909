# AS 65001 — isolated network, no NAT (forward omitted = isolated)
resource "libvirt_network" "as65001" {
  name      = "as65001"
  autostart = true
}

# AS 65002 — isolated network, no NAT
resource "libvirt_network" "as65002" {
  name      = "as65002"
  autostart = true
}

# Interlink — eBGP point-to-point between router1 and router2
resource "libvirt_network" "interlink" {
  name      = "interlink"
  autostart = true
}

# Management — NAT with DHCP, used for Ansible SSH access from host
resource "libvirt_network" "mgmt" {
  name      = "mgmt"
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [{
    address = "192.168.100.1"

    dhcp = {
      ranges = [{
        start = "192.168.100.10"
        end   = "192.168.100.100"
      }]

      # Reserve IPs per hostname so Ansible gets predictable addresses
      hosts = [
        for name, node in var.nodes : {
          hostname = name
          name     = name
          ip       = "192.168.100.${10 + index(keys(var.nodes), name)}"
        }
      ]
    }
  }]
}
