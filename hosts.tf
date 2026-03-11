resource "null_resource" "update_local_hosts" {
  depends_on = [libvirt_domain.vm]

  triggers = {
    node_ips = jsonencode(local.mgmt_ips)
  }

  provisioner "local-exec" {
    command = <<-EOF
      # Remove old block
      sudo sed -i '/# BEGIN lab-909/,/# END lab-909/d' /etc/hosts

      # Add new block
      echo "# BEGIN lab-909" | sudo tee -a /etc/hosts
      %{~for name, ip in local.mgmt_ips~}
      echo "${ip} ${name}" | sudo tee -a /etc/hosts
      %{~endfor~}
      echo "# END lab-909" | sudo tee -a /etc/hosts
    EOF
  }
}
