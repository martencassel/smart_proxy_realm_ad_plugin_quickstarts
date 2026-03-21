@{
    RootModule        = 'AdDelegationTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b1c0a8c1-9f8d-4f0d-9b7e-1e2f0d123456'
    Author            = 'Mårten'
    CompanyName       = 'Local'
    Description       = 'Least-privilege AD delegation tools for managing computer objects in specific OUs.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Grant-AdOuComputerManagementRights')
    PrivateData       = @{}
}
