locals {
  interlink_ips = {
    for name, node in var.nodes : name => node.interlink_ip
    if node.interlink_ip != null
  }
  mgmt_ips = {
    for idx, name in sort(keys(var.nodes)) : name => "192.168.100.${10 + idx}"
  }
  mgmt_macs = {
    for name, _ in var.nodes : name => format(
      "52:54:%s:%s:%s:%s",
      substr(md5("${name}-mgmt"), 0, 2),
      substr(md5("${name}-mgmt"), 2, 2),
      substr(md5("${name}-mgmt"), 4, 2),
      substr(md5("${name}-mgmt"), 6, 2)
    )
  }
  lan_macs = {
    for name, _ in var.nodes : name => format(
      "52:54:%s:%s:%s:%s",
      substr(md5("${name}-lan"), 0, 2),
      substr(md5("${name}-lan"), 2, 2),
      substr(md5("${name}-lan"), 4, 2),
      substr(md5("${name}-lan"), 6, 2)
    )
  }
  interlink_macs = {
    for name, _ in var.nodes : name => format(
      "52:54:%s:%s:%s:%s",
      substr(md5("${name}-interlink"), 0, 2),
      substr(md5("${name}-interlink"), 2, 2),
      substr(md5("${name}-interlink"), 4, 2),
      substr(md5("${name}-interlink"), 6, 2)
    )
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
        mac   = { address = local.mgmt_macs[each.key] }
        model = { type = "virtio" }
        source = { network = {
          network        = libvirt_network.mgmt.name
          wait_for_lease = true
        } }
      }],
      # LAN network — AS65001 or AS65002
      [{
        mac   = { address = local.lan_macs[each.key] }
        model = { type = "virtio" }
        source = { network = {
          network = each.value.network == "as65001" ? libvirt_network.as65001.name : libvirt_network.as65002.name
        } }
      }],
      # Interlink — routers only
      each.value.interlink_ip != null ? [{
        mac   = { address = local.interlink_macs[each.key] }
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
