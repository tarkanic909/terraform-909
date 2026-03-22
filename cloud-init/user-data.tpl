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
  # --- interface rename via udev (.link files) ---
  - path: /etc/systemd/network/10-mgmt0.link
    content: |
      [Match]
      MACAddress=${mgmt_mac}

      [Link]
      Name=mgmt0

  - path: /etc/systemd/network/20-lan0.link
    content: |
      [Match]
      MACAddress=${lan_mac}

      [Link]
      Name=lan0

  %{ if interlink_ip != "" }
  - path: /etc/systemd/network/30-interlink0.link
    content: |
      [Match]
      MACAddress=${interlink_mac}

      [Link]
      Name=interlink0

  %{ endif }
  # --- network configuration (.network files) ---
  - path: /etc/systemd/network/10-mgmt0.network
    content: |
      [Match]
      MACAddress=${mgmt_mac}

      [Network]
      DHCP=ipv4
      %{ if role != "router" ~}

      [DHCPv4]
      UseRoutes=false
      UseGateway=false
      %{ endif ~}

  - path: /etc/systemd/network/20-lan0.network
    content: |
      [Match]
      MACAddress=${lan_mac}

      [Network]
      Address=${lan_cidr}
      %{ if gateway_ip != "" }
      Gateway=${gateway_ip}
      %{ endif }
      %{ if role == "router" ~}
      IPMasquerade=ipv4
      %{ endif ~}

  %{ if interlink_ip != "" }
  - path: /etc/systemd/network/30-interlink0.network
    content: |
      [Match]
      MACAddress=${interlink_mac}

      [Network]
      Address=${interlink_ip}/30

  %{ endif }

runcmd:
  - rm -f /etc/netplan/*.yaml
  - systemctl enable --now systemd-networkd
  - systemctl enable --now systemd-resolved
  - ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  - systemctl enable --now ssh
  - grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  - locale-gen en_US.UTF-8
  - update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US:en

power_state:
  mode: reboot
  condition: true

packages:
  - curl
  - vim
  - tcpdump
  - net-tools

package_update: true
package_upgrade: false
