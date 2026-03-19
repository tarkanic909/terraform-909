variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "debian_image_path" {
  description = "Absolute path to Debian cloud qcow2 image on host"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for ansible user"
  type        = string
}

variable "ansible_user" {
  description = "Name of ansible user on VM"
  type        = string
  default     = "ansible"
}

variable "nodes" {
  description = "Map of all vms in lab"
  type = map(object({
    memory       = number
    vcpu         = number
    disk_size    = optional(number, 10)
    network      = string
    mgmt_ip      = string
    lan_cidr     = string
    bgp_as       = number
    role         = string
    interlink_ip = optional(string, null)
  }))

  validation {
    condition = alltrue([
      for node in values(var.nodes) : contains(["as65001", "as65002"], node.network)
    ])
    error_message = "Each node.network must be either \"as65001\" or \"as65002\"."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) : can(cidrhost("${node.mgmt_ip}/32", 0))
    ])
    error_message = "Each node.mgmt_ip must be a valid IP address."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) : can(cidrhost("${node.lan_cidr}", 0))
    ])
    error_message = "Each node.lan_cidr must be a valid CIDR (e.g., 10.0.1.1/24)."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) : contains(["router", "single", "master", "worker"], node.role)
    ])
    error_message = "Each node.role must be one of: router, single, master, worker."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) : node.memory > 0 && node.vcpu > 0
    ])
    error_message = "Each node must have memory > 0 and vcpu > 0."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) : node.disk_size > 0
    ])
    error_message = "Each node must have disk_size > 0 (GiB)."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) : node.role == "router" ? node.interlink_ip != null : true
    ])
    error_message = "Nodes with role 'router' must have interlink_ip set."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) :
      node.interlink_ip == null ? true : can(cidrhost("${node.interlink_ip}/32", 0))
    ])
    error_message = "Each node.interlink_ip must be a valid IP address."
  }

  validation {
    condition = alltrue([
      for node in values(var.nodes) :
      (node.network == "as65001" && node.bgp_as == 65001) ||
      (node.network == "as65002" && node.bgp_as == 65002)
    ])
    error_message = "node.bgp_as must match node.network: as65001 requires bgp_as=65001, as65002 requires bgp_as=65002."
  }
}
