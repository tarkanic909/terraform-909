locals {
  interlink_neighbors = {
    "lab-router1" = "lab-router2"
    "lab-router2" = "lab-router1"
  }

  interlink_ips = {
    for name, node in var.nodes : name => node.interlink_ip
    if node.interlink_ip != null
  }
  mgmt_ips = {
    for name, node in var.nodes : name => node.mgmt_ip
  }
  # Gateway per node — derived from the router in the same network (empty for routers)
  lan_gateways = {
    for name, node in var.nodes :
    name => node.role == "router" ? "" : try(split("/", [
      for n in values(var.nodes) : n.lan_cidr
      if n.role == "router" && n.network == node.network
    ][0])[0], "")
  }

  # Single MAC map keyed by "name-iface" — avoids repeating the same format/md5 pattern
  macs = {
    for seed in flatten([
      for name in keys(var.nodes) : [
        "${name}-mgmt",
        "${name}-lan",
        "${name}-interlink",
      ]
      ]) : seed => format("52:54:%s:%s:%s:%s",
      substr(md5(seed), 0, 2),
      substr(md5(seed), 2, 2),
      substr(md5(seed), 4, 2),
      substr(md5(seed), 6, 2)
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
        mac   = { address = local.macs["${each.key}-mgmt"] }
        model = { type = "virtio" }
        source = { network = {
          network        = libvirt_network.mgmt.name
          wait_for_lease = true
        } }
      }],
      # LAN network — AS65001 or AS65002
      [{
        mac   = { address = local.macs["${each.key}-lan"] }
        model = { type = "virtio" }
        source = { network = {
          network = each.value.network == "as65001" ? libvirt_network.as65001.name : libvirt_network.as65002.name
        } }
      }],
      # Interlink — routers only
      each.value.interlink_ip != null ? [{
        mac   = { address = local.macs["${each.key}-interlink"] }
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
