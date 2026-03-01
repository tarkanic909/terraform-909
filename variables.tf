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
    memory  = number
    vcpu    = number
    network = string # as65001 | as65002
    lan_ip  = string
    as      = number
    role    = string # router | k3s-master | k3s-worker | host
  }))
  default = {
    "lab-router1" = {
      memory  = 512
      vcpu    = 1
      network = "as65001"
      lan_ip  = "10.0.1.1"
      as      = 65001
      role    = "router"
    }
    "lab-host1" = {
      memory  = 512
      vcpu    = 1
      network = "as65001"
      lan_ip  = "10.0.1.10"
      as      = 0
      role    = "host"
    }
    "lab-router2" = {
      memory  = 512
      vcpu    = 1
      network = "as65002"
      lan_ip  = "10.0.2.1"
      as      = 65002
      role    = "router"
    }
    "lab-k3s-master" = {
      memory  = 2048
      vcpu    = 2
      network = "as65002"
      lan_ip  = "10.0.2.10"
      as      = 65002
      role    = "k3s-master"
    }
    "lab-k3s-w1" = {
      memory  = 1024
      vcpu    = 1
      network = "as65002"
      lan_ip  = "10.0.2.11"
      as      = 65002
      role    = "k3s-worker"
    }
    "lab-k3s-w2" = {
      memory  = 1024
      vcpu    = 1
      network = "as65002"
      lan_ip  = "10.0.2.12"
      as      = 65002
      role    = "k3s-worker"
    }
  }
}
