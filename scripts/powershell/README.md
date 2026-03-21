# Overview

This module can be used to grant least-privilege permission for a service account user to manage computer accounts in
a specific OU.

# Requires
Windows Server 2016 with  ActiveDirectory module installed.

# Install Active Directory module

```powershell
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

Import-Module ActiveDirectory
Get-Command -Module ActiveDirectory
```

# Usage

First creat the service account:

```powershell
# Variables
$Sam = 'svc-OU-ComputerMgmt'
$Ou  = 'OU=Service Accounts,OU=Stockholm,DC=contoso,DC=com'

# 1. Create the service account in a dedicated, locked‑down OU
New-ADUser `
    -Name $Sam `
    -SamAccountName $Sam `
    -Path $Ou `
    -Enabled $true `
    -AccountPassword (Read-Host -AsSecureString 'Enter a strong password') `
    -PasswordNeverExpires $true `
    -CannotChangePassword $true `
    -Description 'Service account for delegated computer management in Stockholm OU' `
    -PassThru

# 2. Prevent interactive logon (recommended)
# Apply the "Deny log on locally" and "Deny log on through Remote Desktop Services" rights
# via GPO to the Service Accounts OU.

# 3. Prevent Kerberos delegation unless explicitly required
Set-ADAccountControl -Identity $Sam -TrustedForDelegation $false

# 4. Ensure the account is not a member of any privileged groups
Get-ADUser $Sam -Properties MemberOf | Select-Object -ExpandProperty MemberOf
```

Then grant the access

```powershell
Import-Module ./AdDelegationTools

Grant-AdOuComputerManagementRights `
    -OrganizationalUnitDn 'OU=Workstations,OU=Stockholm,DC=contoso,DC=com' `
    -ServiceAccountSam 'svc-OU-ComputerMgmt'
```
