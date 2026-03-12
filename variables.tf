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
  sensitive   = true
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
    network      = string # as65001 | as65002
    lan_ip       = string
    as           = number
    role         = string  # router | single | master | worker
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
      for node in values(var.nodes) : node.role == "router" ? node.interlink_ip != null : true
    ])
    error_message = "Nodes with role 'router' must have interlink_ip set."
  }
  default = {
    "lab-router1" = {
      memory       = 512
      vcpu         = 1
      network      = "as65001"
      lan_ip       = "10.0.1.1"
      as           = 65001
      role         = "router"
      interlink_ip = "10.0.0.1"
    }
    "lab-k3s-single" = {
      memory  = 2048
      vcpu    = 2
      network = "as65001"
      lan_ip  = "10.0.1.10"
      as      = 65001
      role    = "single"
    }
    "lab-router2" = {
      memory       = 512
      vcpu         = 1
      network      = "as65002"
      lan_ip       = "10.0.2.1"
      as           = 65002
      role         = "router"
      interlink_ip = "10.0.0.2"
    }
    "lab-k3s-master" = {
      memory  = 2048
      vcpu    = 2
      network = "as65002"
      lan_ip  = "10.0.2.10"
      as      = 65002
      role    = "master"
    }
    "lab-k3s-w1" = {
      memory  = 1024
      vcpu    = 1
      network = "as65002"
      lan_ip  = "10.0.2.11"
      as      = 65002
      role    = "worker"
    }
    "lab-k3s-w2" = {
      memory  = 1024
      vcpu    = 1
      network = "as65002"
      lan_ip  = "10.0.2.12"
      as      = 65002
      role    = "worker"
    }
  }
}
