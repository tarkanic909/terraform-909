locals {
  interlink_ips = {
    "vm-router1" = "10.0.0.1"
    "vm-router2" = "10.0.0.2"
  }
}

# VM definitions
resource "libvirt_domain" "vm" {
  for_each = var.nodes

  name        = each.key
  memory      = each.value.memory
  memory_unit = "MiB"
  vcpu        = each.value.vcpu
  type        = "kvm"
  running     = true

  os = {
    type      = "hvm"
    type_arch = "x86_64"
    boot_devices = [
      { dev = "hd" }
    ]
  }

  devices = {
    disks = concat(
      # System disk
      [{
        driver = { type = "qcow2" }
        source = {
          file = { file = libvirt_volume.vm_disk[each.key].path }
        }
        target = { dev = "vda", bus = "virtio" }
      }],
      # Cloud-init CDROM
      [{
        device = "cdrom"
        driver = { type = "raw" }
        source = {
          file = { file = libvirt_volume.cloud_init[each.key].path }
        }
        target = { dev = "sda", bus = "ide" }
      }]
    )

    interfaces = concat(
      # Management network — always present, wait for DHCP lease
      [{
        model = { type = "virtio" }
        source = { network = {
          network        = libvirt_network.mgmt.name
          wait_for_lease = true
        } }
      }],
      # LAN network — AS65001 or AS65002
      [{
        model = { type = "virtio" }
        source = { network = {
          network = each.value.network == "as65001" ? libvirt_network.as65001.name : libvirt_network.as65002.name
        } }
      }],
      # Interlink — routers only
      contains(keys(local.interlink_ips), each.key) ? [{
        model = { type = "virtio" }
        source = { network = {
          network = libvirt_network.interlink.name
        } }
      }] : []
    )

    consoles = [{
      type   = "pty"
      target = { type = "serial", port = 0 }
    }]
  }
}

# output "vm_mgmt_ips" {
#   description = "Management IPs — use these for Ansible inventory"
#   value = {
#     for name, domain in libvirt_domain.vm :
#     name => domain.devices.interfaces[0].source.network.ip
#   }
# }
