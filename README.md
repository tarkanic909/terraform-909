# Terraform Libvirt Lab

Terraform project for a local `libvirt` (KVM/QEMU) lab with this topology:
- `mgmt` (NAT + DHCP) for SSH/Ansible access
- `as65001` and `as65002` (isolated LAN segments)
- `interlink` (point-to-point between routers)

The current plan creates 6 VMs:
- `lab-router1`, `lab-router2`
- `lab-k3s-single`
- `lab-k3s-master`, `lab-k3s-w1`, `lab-k3s-w2`

## Requirements

- Linux host with working KVM/libvirt
- Terraform
- `jq`
- `virsh`
- `sudo` privileges for `virsh` operations in the Makefile
- Debian cloud image (`.qcow2`) available on the host

## Tested Versions

- Terraform: `1.14.6`
- Terraform provider `dmacvicar/libvirt`: `0.9.3` (constraint `~> 0.9.0`)
- libvirt (`virsh --version`): `11.3.0`
- QEMU (`qemu-system-x86_64 --version`): `10.0.7`

## Configuration

1. Copy the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Update values in `terraform.tfvars`:
- `libvirt_uri` (default `qemu:///system`)
- `debian_image_path` (absolute image path)
- `ssh_public_key`
- `ansible_user`

Note: `terraform.tfvars` is in `.gitignore`.

## Quick Start

```bash
make init
make validate
make plan
make apply
```

Or run everything in one command:

```bash
make lab-up
```

## Common Commands

- `make help` - list all available targets
- `make fmt` - format Terraform files
- `make fmt-check` - check formatting
- `make validate` - `fmt-check` + `terraform validate`
- `make plan` - save plan to `labplan`
- `make apply` - apply saved `labplan`
- `make destroy` - destroy all Terraform resources
- `make lab-down` - alias for `destroy`
- `make info` - print `node_info` as JSON
- `make inventory` - generate a simple Ansible inventory

Libvirt utility targets:
- `make lab-list` - list VMs with `lab-` prefix
- `make vms-stop` - stop running `lab-` VMs
- `make vms-start` - start all `lab-` VMs
- `make vms-undefine` - undefine `lab-` VMs and remove storage

## Outputs

`terraform output -json node_info` includes:
- VM name
- management IP
- memory
- vCPU

Same output via:

```bash
make info
```

## Topology (Summary)

- `mgmt`: `192.168.100.0/24`, gateway `192.168.100.1`, per-node DHCP reservations
- `as65001`: `10.0.1.0/24`
- `as65002`: `10.0.2.0/24`
- `interlink`: `10.0.0.0/29` (router1 `10.0.0.1`, router2 `10.0.0.2`)

## Troubleshooting

- Provider plugin error in sandbox (`Failed to load plugin schemas` / `setsockopt: operation not permitted`):
  - run Terraform directly on the host (not in a restricted sandbox).
- `debian_image_path` does not exist:
  - verify the absolute path in `terraform.tfvars`.
- `virsh` commands prompt for password or fail:
  - verify `sudo` privileges and access to `qemu:///system`.

## Notes

- `make clean` removes `labplan` and `.terraform`.
- Before `make apply`, always review `terraform plan` output.
