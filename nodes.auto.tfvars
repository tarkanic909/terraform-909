nodes = {
  "lab-router1" = {
    memory       = 512
    vcpu         = 1
    disk_size    = 5
    network      = "as65001"
    mgmt_ip      = "192.168.100.10"
    lan_cidr     = "10.0.1.1/24"
    bgp_as       = 65001
    role         = "router"
    interlink_ip = "10.0.0.1"
  }
  "lab-k3s-single" = {
    memory    = 2048
    vcpu      = 2
    disk_size = 20
    network   = "as65001"
    mgmt_ip   = "192.168.100.11"
    lan_cidr  = "10.0.1.10/24"
    bgp_as    = 65001
    role      = "single"
  }
  "lab-router2" = {
    memory       = 512
    vcpu         = 1
    disk_size    = 5
    network      = "as65002"
    mgmt_ip      = "192.168.100.12"
    lan_cidr     = "10.0.2.1/24"
    bgp_as       = 65002
    role         = "router"
    interlink_ip = "10.0.0.2"
  }
  "lab-k3s-master" = {
    memory    = 2048
    vcpu      = 2
    disk_size = 20
    network   = "as65002"
    mgmt_ip   = "192.168.100.13"
    lan_cidr  = "10.0.2.10/24"
    bgp_as    = 65002
    role      = "master"
  }
  "lab-k3s-w1" = {
    memory    = 1024
    vcpu      = 1
    disk_size = 10
    network   = "as65002"
    mgmt_ip   = "192.168.100.14"
    lan_cidr  = "10.0.2.11/24"
    bgp_as    = 65002
    role      = "worker"
  }
  "lab-k3s-w2" = {
    memory    = 1024
    vcpu      = 1
    disk_size = 10
    network   = "as65002"
    mgmt_ip   = "192.168.100.15"
    lan_cidr  = "10.0.2.12/24"
    bgp_as    = 65002
    role      = "worker"
  }
}
