# Smart Proxy Realm AD Plugin Quickstart

This guide describes how to install and configure Foreman Smart Proxy with the Active Directory realm plugin on RHEL 9.7.

## Use Cases

### UC1. User Creates Host
Goal: Build a Linux server that can be joined automatically and securely to Active Directory after install.

### UC2. User Updates Host
Goal: Reinstall a Linux server and rejoin it automatically and securely to Active Directory.
Goal: Keep the computer name.

### UC3. User Deletes Host
Goal: Remove a Linux server and automatically remove its account from Active Directory.

### UC4. Provisioning Template
Goal: Provide a one-time password from Foreman in the provisioning template to join the computer to Active Directory.
Goal: Use a computer account already created by the Foreman realm plugin with this password.
Goal: Join the Linux server using an unprivileged join account.
Goal: Avoid joining with an admin account or storing an admin password on the server.

### UC5. Sign in to the Server Using a Domain Account
Goal: Allow a user to log in with an AD account after first boot.
Goal: Ensure the server has been joined using the temporary computer account password.
Goal: One can sign-in into Active Directory on the machine, SSSD is managing the connection etc, sudo policies etc.
      Kerberos, kinit tickets work etc.

### UC6. Linux servers computer accounts shall be placed in a specific OU in AD

### UC7. Newly create computer account for servers shall have a prefix for them

### UC8. Use the FQDN as the computer name.

### UC9. Use a digest of the computer name as the computer name (SHA256)

### UC10. The plugin can provision Active Directory in a multi DC environment, that might be down


## Prerequisite

Verify that the host is RHEL 9.7:

```bash
grep -q "release 9.7" /etc/redhat-release && echo "RHEL 9.7" || echo "Not RHEL 9.7"
```

## 1. Configure Network (Static IP)

Replace the IP values as needed:

```bash
nmcli con mod "$(nmcli -t -f NAME con show --active | head -n1)" \
  ipv4.addresses 192.168.0.5/24 \
  ipv4.gateway 192.168.0.1 \
  ipv4.dns "8.8.8.8 1.1.1.1" \
  ipv4.method manual

nmcli con up "$(nmcli -t -f NAME con show --active | head -n1)"
```

## 2. Disable Firewall (Optional)

```bash
systemctl disable firewalld --now
```

## 3. Update System and Install Basic Tools

```bash
sudo -i
subscription-manager register --username marten.cassel@conoa.se --org 6698658
dnf update && dnf -y install vim
```

## 4. Set Hostname

```bash
hostnamectl set-hostname foreman.lab
echo "192.168.0.12 foreman.lab" | tee -a /etc/hosts > /dev/null
```

## 5. Add Repositories and Upgrade

```bash
sudo -i

dnf clean all
dnf install -y https://yum.theforeman.org/releases/3.18/el9/x86_64/foreman-release.rpm
dnf install -y https://yum.puppet.com/puppet8-release-el-9.noarch.rpm
dnf repolist enabled
dnf upgrade
```

Install Foreman installer:

```bash
dnf install -y foreman-installer
```

## 6. Install AD Realm Plugin

```bash
dnf install -y rubygem-smart_proxy_realm_ad_plugin.noarch
```

## 7. Run the Installer

```bash
foreman-installer \
  --foreman-proxy-realm=true \
  --foreman-proxy-realm-provider=ad
```

## 8. Check Installer Logs

```bash
cat /var/log/foreman-proxy/proxy.log
cat /var/log/foreman-installer/foreman.log
```

## 9. Verify Services and Proxy Features

Check service status:

```bash
systemctl status foreman
systemctl status foreman-proxy
```

Check listening ports:

```bash
sudo dnf install net-tools
netstat -tulpen
```

Verify Smart Proxy features:

```bash
curl -k \
  --cert /etc/puppetlabs/puppet/ssl/certs/$(hostname -f).pem \
  --key /etc/puppetlabs/puppet/ssl/private_keys/$(hostname -f).pem \
  --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem \
  https://foreman.lab:8443/v2/features | jq
```

## 10. Example Realm AD Configuration

File: /etc/foreman-proxy/settings.d/realm_ad.yml

```yaml
---
# Authentication for Kerberos-based realms
:realm: EXAMPLE.COM

# Kerberos principal used to authenticate against Active Directory
:principal: realm-proxy@EXAMPLE.COM

# Path to the keytab used to authenticate against Active Directory
:keytab_path: /etc/foreman-proxy/realm_ad.keytab

# FQDN of the domain controller
:domain_controller: dc.example.com

# Optional: OU where the machine account shall be placed
#:ou: OU=Linux,OU=Servers,DC=example,DC=com

# Optional: Prefix for computer name
#:computername_prefix: ''

# Optional: Hash hostname for computer name
#:computername_hash: false

# Optional: Use FQDN as computer name
#:computername_use_fqdn: false
```

## 11. Create a Keytab

```bash
adcli create-user foreman-proxy --domain=example.com
adcli passwd-user --domain=example.com foreman-proxy

Password for Administrator@EXAMPLE.COM:
Password for foreman-proxy:
```

```bash
ktutil

addent -password -p foreman-proxy@EXAMPLE.COM -k 1 -e aes256-cts-hmac-sha1-96
addent -password -p foreman-proxy@EXAMPLE.COM -k 1 -e aes128-cts-hmac-sha1-96
wkt /tmp/realm.keytab
quit
```

```bash
kinit -kt /tmp/realm.keytab foreman-proxy@EXAMPLE.COM
```
