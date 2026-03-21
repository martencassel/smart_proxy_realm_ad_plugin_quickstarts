function Grant-AdOuComputerManagementRights {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $OrganizationalUnitDn,

        [Parameter(Mandatory)]
        [string] $ServiceAccountSam
    )

    Import-Module ActiveDirectory -ErrorAction Stop

    $ou   = Get-ADOrganizationalUnit -Identity $OrganizationalUnitDn
    $user = Get-ADUser -Identity $ServiceAccountSam
    $sid  = New-Object System.Security.Principal.SecurityIdentifier($user.SID)

    $de  = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($ou.DistinguishedName)")
    $acl = $de.ObjectSecurity

    # GUIDs
    $computerClassGuid = [Guid]'bf967a86-0de6-11d0-a285-00aa003049e2'
    $resetPwdGuid      = [Guid]'00299570-246d-11d0-a768-00aa006e0529'

    $inherit = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All

    # Create computer objects
    $acl.AddAccessRule(
        [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
            $sid,
            [System.DirectoryServices.ActiveDirectoryRights]::CreateChild,
            'Allow',
            $computerClassGuid,
            $inherit
        )
    )

    # Delete computer objects
    $acl.AddAccessRule(
        [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
            $sid,
            [System.DirectoryServices.ActiveDirectoryRights]::DeleteChild,
            'Allow',
            $computerClassGuid,
            $inherit
        )
    )

    # Reset computer password
    $acl.AddAccessRule(
        [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
            $sid,
            [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
            'Allow',
            $resetPwdGuid,
            $inherit
        )
    )

    # Write basic attributes (description, etc.)
    $acl.AddAccessRule(
        [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
            $sid,
            [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty,
            'Allow',
            $computerClassGuid,
            $inherit
        )
    )

    # Commit
    $de.ObjectSecurity = $acl
    $de.CommitChanges()

    Write-Verbose "Delegation applied to $OrganizationalUnitDn for $ServiceAccountSam"
}
