# Copy this file to terraform.tfvars and fill in your values
# terraform.tfvars is in .gitignore — never commit it!

libvirt_uri = "qemu:///system"

# Full path to the Debian cloud qcow2 image on the host
debian_image_path = "/home/data909/projects/cluster/debian-13-genericcloud-amd64.qcow2"

# Your SSH public key
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAKC2arWJItYQA5KxYiH2gEijspMWcZwva/ISqU9xEM3"

ansible_user = "ansible"
