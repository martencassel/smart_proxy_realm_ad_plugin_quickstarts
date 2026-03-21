#!/usr/bin/env bash
set -euo pipefail

PRINCIPAL="realm-proxy@EXAMPLE.COM"
KEYTAB="/etc/foreman-proxy/realm_ad.keytab"

echo "Creating keytab for $PRINCIPAL"
read -s -p "Enter password for $PRINCIPAL: " PASSWORD
echo

# Create temporary command file for ktutil
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" <<EOF
addent -password -p $PRINCIPAL -k 1 -e aes256-cts-hmac-sha1-96
$PASSWORD
addent -password -p $PRINCIPAL -k 1 -e aes128-cts-hmac-sha1-96
$PASSWORD
wkt $KEYTAB
quit
EOF

sudo ktutil < "$TMPFILE"

sudo chmod 600 "$KEYTAB"
sudo chown root:root "$KEYTAB"

echo "Keytab written to $KEYTAB"
echo "Validating…"
kinit -kt "$KEYTAB" "$PRINCIPAL"
klist
