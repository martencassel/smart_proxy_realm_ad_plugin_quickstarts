param(
    [Parameter(Mandatory=$true)]
    [string]$SamAccountName,

    [Parameter(Mandatory=$true)]
    [string]$Realm,

    [Parameter(Mandatory=$true)]
    [string]$Password,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

$principal = "$SamAccountName@$Realm"
$domainUser = "$($env:USERDOMAIN)\$SamAccountName"

Write-Host "Generating keytab for $principal"

ktpass `
  -princ $principal `
  -mapuser $domainUser `
  -crypto AES256-SHA1 `
  -ptype KRB5_NT_PRINCIPAL `
  -pass $Password `
  -out $OutputPath `
  -kvno 0

Write-Host "Keytab written to $OutputPath"
Write-Host "Copy this file to your Linux host and validate with:"
Write-Host "  kinit -kt $OutputPath $principal"
