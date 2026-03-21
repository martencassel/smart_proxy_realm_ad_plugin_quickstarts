#!/bin/bash

dnf install -y nmap-ncat bind-utils krb5-workstation adcli realmd
dig +short _ldap._tcp.$DOMAIN SRV
for port in 53 88 389 445 464; do
  echo -n "Port $port: "
  nc -z -w2 "$DC" "$port" && echo "OK" || echo "FAIL"
done
dig +short "$DC"
dig +short _kerberos._tcp.$DOMAIN SRV
dig +short _ldap._tcp.$DOMAIN SRV
IP=$(dig +short "$DC")
dig +short -x "$IP"
kinit -V "$TEST_USER"
klist
adcli info "$DOMAIN"
adcli info --verbose "$DOMAIN"

