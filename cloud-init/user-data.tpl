#cloud-config

hostname: ${hostname}
fqdn: ${hostname}.lab.local
manage_etc_hosts: true
locale: en_US.UTF-8

users:
  - name: ${ansible_user}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_public_key}

ssh_pwauth: false
disable_root: true

write_files:
  - path: /etc/netplan/00-lab.yaml
    content: |
      network:
        version: 2
        ethernets:
          enp1s0:
            dhcp4: true
          enp2s0:
            dhcp4: false
            addresses:
              - ${lan_ip}/24
          %{ if interlink_ip != "" }
          enp3s0:
            dhcp4: false
            addresses:
              - ${interlink_ip}/29
          %{ endif }

runcmd:
  - netplan apply
  - systemctl enable --now ssh
  - locale-gen
  - update-locale LC_ALL=en_US.UTF=8 LANG=en_US.UTF-8 LANGUAGE=en_US:en

packages:
  - curl
  - vim
  - tcpdump
  - net-tools

package_update: true
