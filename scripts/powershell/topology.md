# Simple AD Topology

## Network

- One flat L2 subnet (eg. 192.168.0.0/24)
- All DCs and Linux live in the same VLAN / LAN
- No routing, no multi-site complexity

## Domain Controllers

- DC1: first DC, all FSMO roles, DNS, Global Catalog
- DC2: additional DC, DNS, Global Catalog
- DC3: additional DC, DNS, Global Catalog

## DNS for linux hosts

```
nameserver <DC1-IP>
nameserver <DC2-IP>
nameserver <DC3-IP>
search example.com
````

## AD Site 

Create one site (e.g., HQ)
Assign the subnet and all three DCs to it


## Linux Integration

Join using realm join or adcli join
Kerberos realm: EXAMPLE.COM
DNS must point to the DCs

