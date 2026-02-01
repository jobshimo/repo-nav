<#
.SYNOPSIS
    GeneralPreferences - Strongly typed model for general settings
#>
class GeneralPreferences {
    [string] $Language = "en"
    [bool] $DebugMode = $false

    GeneralPreferences() {}
}
