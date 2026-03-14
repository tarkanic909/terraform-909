# Base image — loaded once, shared across all VM disks (copy-on-write)
resource "libvirt_volume" "base_image" {
  name = "debian-base.qcow2"
  pool = "default"

  target = {
    format = { type = "qcow2" }
  }

  create = {
    content = {
      url = "file://${var.debian_image_path}"
    }
  }
}

# System disk — thin qcow2 overlay on top of base image
resource "libvirt_volume" "vm_disk" {
  for_each      = var.nodes
  name          = "${each.key}-disk.qcow2"
  pool          = "default"
  capacity      = each.value.disk_size
  capacity_unit = "GiB"

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = libvirt_volume.base_image.target.path
    format = { type = "qcow2" }
  }
}

# Cloud-init config disk
resource "libvirt_cloudinit_disk" "init" {
  for_each = var.nodes

  name = "${each.key}-cidata.iso"

  user_data = templatefile("${path.module}/cloud-init/user-data.tpl", {
    hostname       = each.key
    ansible_user   = var.ansible_user
    ssh_public_key = var.ssh_public_key
    lan_ip         = each.value.lan_ip
    interlink_ip   = lookup(local.interlink_ips, each.key, "")
    mgmt_mac       = local.macs["${each.key}-mgmt"]
    lan_mac        = local.macs["${each.key}-lan"]
    interlink_mac  = local.macs["${each.key}-interlink"]
  })

  meta_data = yamlencode({
    instance-id    = each.key
    local-hostname = each.key
  })
}

# Cloud-init ISO as a volume (required to attach to VM in 0.9.x)
resource "libvirt_volume" "cloud_init" {
  for_each = var.nodes
  name     = "${each.key}-cidata.iso"
  pool     = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.init[each.key].path
    }
  }
}
