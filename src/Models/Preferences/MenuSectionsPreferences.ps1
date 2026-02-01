<#
.SYNOPSIS
    MenuSectionsPreferences - Strongly typed model for menu section visibility
#>
class MenuSectionsPreferences {
    [bool] $Navigation = $true
    [bool] $Alias = $true
    [bool] $Modules = $true
    [bool] $Repository = $true
    [bool] $Paths = $true
    [bool] $Git = $true
    [bool] $Tools = $true

    MenuSectionsPreferences() {}
}
