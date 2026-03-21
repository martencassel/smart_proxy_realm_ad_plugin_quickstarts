# Step 1. On DC1: create the new forest "example.com"

# 1. Install AD DS role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 2. Create new forest: example.com
Install-ADDSForest `
  -DomainName "example.com" `
  -DomainNetbiosName "EXAMPLE" `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password") `
  -InstallDNS `
  -Force

# Step 2. On DC2 – join domain, then promote as additional DC
#

# 1. Join DC2 to the domain (run as local admin)
Add-Computer -DomainName "example.com" -Credential "EXAMPLE\Administrator" -Restart

After reboot, log on with domain credentials, then:

# 2. Install AD DS role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 3. Promote DC2 as additional domain controller
Install-ADDSDomainController `
  -DomainName "example.com" `
  -Credential (Get-Credential "EXAMPLE\Administrator") `
  -InstallDNS `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password") `
  -Force

DC2 will reboot as DC2.example.com.

# Step 3. On DC3 – same pattern as DC2
#

# 1. Join DC3 to the domain
Add-Computer -DomainName "example.com" -Credential "EXAMPLE\Administrator" -Restart

After rebot:

# 2. Install AD DS role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 3. Promote DC3 as additional domain controller
Install-ADDSDomainController `
  -DomainName "example.com" `
  -Credential (Get-Credential "EXAMPLE\Administrator") `
  -InstallDNS `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password") `
  -Force

# Step 4. Quick health checks (from any DC)

# # Replication and DC health
dcdiag /v
repadmin /replsummary
Get-ADDomainController -Filter * | Select-Object HostName,Site,IPv4Address




