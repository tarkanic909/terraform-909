# Networking

## Topology

```
Host machine
│
├── mgmt (192.168.100.0/24, NAT)        ← SSH / Ansible access from host
│   ├── lab-router1      192.168.100.10
│   ├── lab-k3s-single   192.168.100.11
│   ├── lab-router2      192.168.100.12
│   ├── lab-k3s-master   192.168.100.13
│   ├── lab-k3s-w1       192.168.100.14
│   └── lab-k3s-w2       192.168.100.15
│
├── as65001 (10.0.1.0/24, isolated)     ← internal network AS 65001
│   ├── lab-router1      10.0.1.1
│   └── lab-k3s-single   10.0.1.10
│
├── as65002 (10.0.2.0/24, isolated)     ← internal network AS 65002
│   ├── lab-router2      10.0.2.1
│   ├── lab-k3s-master   10.0.2.10
│   ├── lab-k3s-w1       10.0.2.11
│   └── lab-k3s-w2       10.0.2.12
│
└── interlink (10.0.0.0/29, isolated)   ← eBGP point-to-point
    ├── lab-router1      10.0.0.1
    └── lab-router2      10.0.0.2
```

> **Note:** `10.0.0.0/29` is the overall interlink address space.
> Each interface uses a `/30` mask (point-to-point pair), as seen in `cloud-init/user-data.tpl`: `Address=${interlink_ip}/30`.

Each VM has 2 or 3 network interfaces depending on its role:
- `router` — mgmt + lan + interlink
- others — mgmt + lan

---

## How Terraform assigns MAC addresses

MAC addresses are **deterministically generated** from the node name and interface name using an MD5 hash.

### Algorithm (`nodes.tf`)

```hcl
macs = {
  for seed in ["lab-router1-mgmt", "lab-router1-lan", ...] :
  seed => format("52:54:%s:%s:%s:%s",
    substr(md5(seed), 0, 2),
    substr(md5(seed), 2, 2),
    substr(md5(seed), 4, 2),
    substr(md5(seed), 6, 2)
  )
}
```

The seed string has the form `"<node-name>-<iface>"`, e.g. `"lab-router1-mgmt"`.
The first 8 hex characters of the MD5 hash (32 hex chars total) are used = 4 octets.
The `52:54` prefix is the standard OUI for KVM/QEMU virtual NICs.

Example:
```
seed:  lab-router1-mgmt
md5:   8b1a3f2c...
mac:   52:54:8b:1a:3f:2c
```

Benefits of this approach:
- MAC is always the same for a given node — `terraform apply` will not change it
- Requires no external state or counter
- Each interface has a unique MAC (different seed)

---

## How Terraform assigns IP addresses

### Management network (mgmt)

The IP is defined explicitly in `nodes.auto.tfvars` as `mgmt_ip`:

```hcl
"lab-router1" = {
  mgmt_ip = "192.168.100.10"
  ...
}
```

The libvirt DHCP server has static reservations — it assigns an IP based on the MAC:

```hcl
# network.tf
hosts = [
  for name, _ in var.nodes : {
    mac = local.macs["${name}-mgmt"]   # deterministic MAC
    ip  = local.mgmt_ips[name]         # = node.mgmt_ip
  }
]
```

Result: the VM always gets the same IP regardless of boot order.

Terraform waits for the DHCP lease (`wait_for_lease = true` on the mgmt interface) before marking the resource as ready.

### LAN and Interlink networks

IPs are also defined explicitly in `nodes.auto.tfvars` (`lan_cidr`, `interlink_ip`).
These networks **have no DHCP** — they are isolated (no NAT, no DHCP server).
IPs are configured directly on the VM via cloud-init → systemd-networkd.

### Gateway for LAN interfaces

The gateway is **dynamically computed** in `nodes.tf` (`lan_gateways`):

```hcl
# nodes.tf
lan_gateways = {
  for name, node in var.nodes :
  name => node.role == "router" ? "" : try(split("/", [
    for n in values(var.nodes) : n.lan_cidr
    if n.role == "router" && n.network == node.network
  ][0])[0], "")
}
```

- Routers have no gateway (empty string).
- Other nodes receive the IP of the router in the same network (first IP from the router's `lan_cidr`).
- The gateway is written to the `.network` file only if it is non-empty (`%{ if gateway_ip != "" }`).

---

## How systemd-networkd uses MAC addresses

Cloud-init writes two types of files into the VM for each interface.

### `.link` files — interface renaming

Processed by `udev` when a network device is detected.
The interface is renamed based on MAC → custom name.

```ini
# /etc/systemd/network/10-mgmt0.link
[Match]
MACAddress=52:54:8b:1a:3f:2c

[Link]
Name=mgmt0
```

After renaming: `eth0` (or `ens3`) → `mgmt0`.

### `.network` files — IP configuration

Processed by `systemd-networkd`.
Also matched by MAC — works on first boot before renaming.

```ini
# /etc/systemd/network/10-mgmt0.network
[Match]
MACAddress=52:54:8b:1a:3f:2c

[Network]
DHCP=ipv4
```

```ini
# /etc/systemd/network/20-lan0.network
[Match]
MACAddress=52:54:...

[Network]
Address=10.0.1.1/24
```

### Why match by MAC and not by name?

The `.link` file is applied on the first `udev` event — which may happen after
`systemd-networkd` has already processed the `.network` files. Matching by MAC
ensures correct configuration even when the interface does not yet have its final name.

### Full first-boot flow

```
1. QEMU creates the VM with MAC addresses defined in Terraform
2. Cloud-init writes .link and .network files
3. systemd-networkd starts, matches interfaces by MAC
4. mgmt0 gets an IP via DHCP (reservation by MAC → deterministic IP)
5. lan0 gets a static IP; interlink0 only if interlink_ip != "" (routers)
6. Terraform detects the DHCP lease on mgmt → resource is ready
7. /etc/hosts on the host is updated (null_resource provisioner)
```

> **Conditional interface:** Files for `interlink0` are generated in cloud-init only for nodes
> with a non-empty `interlink_ip` (role `router`). Non-router nodes have only `mgmt0` and `lan0`.
