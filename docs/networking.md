# Networking

## Topológia

```
Host machine
│
├── mgmt (192.168.100.0/24, NAT)        ← SSH / Ansible prístup z hosta
│   ├── lab-router1      192.168.100.10
│   ├── lab-k3s-single   192.168.100.11
│   ├── lab-router2      192.168.100.12
│   ├── lab-k3s-master   192.168.100.13
│   ├── lab-k3s-w1       192.168.100.14
│   └── lab-k3s-w2       192.168.100.15
│
├── as65001 (10.0.1.0/24, isolated)     ← interná sieť AS 65001
│   ├── lab-router1      10.0.1.1
│   └── lab-k3s-single   10.0.1.10
│
├── as65002 (10.0.2.0/24, isolated)     ← interná sieť AS 65002
│   ├── lab-router2      10.0.2.1
│   ├── lab-k3s-master   10.0.2.10
│   ├── lab-k3s-w1       10.0.2.11
│   └── lab-k3s-w2       10.0.2.12
│
└── interlink (10.0.0.0/29, isolated)   ← eBGP point-to-point
    ├── lab-router1      10.0.0.1
    └── lab-router2      10.0.0.2
```

Každý VM má 2 alebo 3 sieťové rozhrania podľa roly:
- `router` — mgmt + lan + interlink
- ostatné — mgmt + lan

---

## Ako Terraform prideľuje MAC adresy

MAC adresy sú **deterministicky generované** z názvu nodu a názvu rozhrania pomocou MD5 hashu.

### Algoritmus (`nodes.tf`)

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

Seed string má tvar `"<node-name>-<iface>"`, napr. `"lab-router1-mgmt"`.
Z MD5 hashu (32 hex znakov) sa vezme prvých 8 znakov = 4 oktety.
Prefix `52:54` je štandardný OUI pre KVM/QEMU virtuálne NIC.

Príklad:
```
seed:  lab-router1-mgmt
md5:   8b1a3f2c...
mac:   52:54:8b:1a:3f:2c
```

Výhody tohto prístupu:
- MAC je vždy rovnaká pre daný nod — `terraform apply` ju nezmení
- Nevyžaduje externý stav ani counter
- Každé rozhranie má unikátnu MAC (rôzny seed)

---

## Ako Terraform prideľuje IP adresy

### Management sieť (mgmt)

IP je definovaná explicitne v `nodes.auto.tfvars` ako `mgmt_ip`:

```hcl
"lab-router1" = {
  mgmt_ip = "192.168.100.10"
  ...
}
```

DHCP server v libvirt má statické rezervácie — priradí IP podľa MAC:

```hcl
# network.tf
hosts = [
  for name, _ in var.nodes : {
    mac = local.macs["${name}-mgmt"]   # deterministická MAC
    ip  = local.mgmt_ips[name]         # = node.mgmt_ip
  }
]
```

Výsledok: VM vždy dostane tú istú IP bez ohľadu na poradie bootu.

Terraform čaká na DHCP lease (`wait_for_lease = true` na mgmt interface) pred tým, ako označí resource za hotový.

### LAN a Interlink siete

IP je tiež definovaná explicitne v `nodes.auto.tfvars` (`lan_ip`, `interlink_ip`).
Tieto siete **nemajú DHCP** — sú isolated (bez NAT, bez DHCP servera).
IP sa konfiguruje priamo na VM cez cloud-init → systemd-networkd.

---

## Ako systemd-networkd používa MAC adresy

Cloud-init zapíše do VM dva typy súborov pre každé rozhranie.

### `.link` súbory — premenovanie rozhrania

Spracúva ich `udev` pri detekcii sieťového zariadenia.
Rozhranie sa premenuje podľa MAC → custom meno.

```ini
# /etc/systemd/network/10-mgmt0.link
[Match]
MACAddress=52:54:8b:1a:3f:2c

[Link]
Name=mgmt0
```

Po premenovaní: `eth0` (alebo `ens3`) → `mgmt0`.

### `.network` súbory — konfigurácia IP

Spracúva ich `systemd-networkd`.
Matchujú tiež podľa MAC — fungujú aj na prvom boote pred premenovaním.

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

### Prečo matchovať podľa MAC a nie podľa mena?

`.link` súbor sa aplikuje pri prvom `udev` evente — čo môže byť po tom, ako
`systemd-networkd` už spracoval `.network` súbory. Matchovanie podľa MAC
zabezpečí správnu konfiguráciu aj keď rozhranie ešte nemá finálne meno.

### Celý flow prvého bootu

```
1. QEMU vytvorí VM s MAC adresami definovanými v Terraform
2. Cloud-init zapíše .link a .network súbory
3. systemd-networkd štartuje, matchuje rozhrania podľa MAC
4. mgmt0 dostane IP cez DHCP (rezervácia podľa MAC → deterministická IP)
5. lan0 / interlink0 dostanú statické IP
6. Terraform detekuje DHCP lease na mgmt → resource je hotový
7. /etc/hosts na hoste sa aktualizuje (null_resource provisioner)
```
