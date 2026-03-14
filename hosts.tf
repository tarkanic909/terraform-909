resource "null_resource" "update_local_hosts" {
  depends_on = [libvirt_domain.vm]

  triggers = {
    node_ips = jsonencode(local.mgmt_ips)
  }

  provisioner "local-exec" {
    command = <<-EOF
      sudo sed -i '/# BEGIN lab-909/,/# END lab-909/d' /etc/hosts
      printf '# BEGIN lab-909\n%{~for name, ip in local.mgmt_ips~}${ip} ${name}\n%{~endfor~}# END lab-909\n' | sudo tee -a /etc/hosts
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo sed -i '/# BEGIN lab-909/,/# END lab-909/d' /etc/hosts"
  }
}
