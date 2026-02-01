<#
.SYNOPSIS
    RepositoryPreferences - Strongly typed model for repository settings
#>
class RepositoryPreferences {
    [string] $DefaultPath = ""
    [string[]] $Paths = @()
    [hashtable] $PathAliases = @{}
    [string[]] $Favorites = @()

    RepositoryPreferences() {}
}
