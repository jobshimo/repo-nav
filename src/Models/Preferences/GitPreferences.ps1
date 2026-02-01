<#
.SYNOPSIS
    GitPreferences - Strongly typed model for Git integration settings
#>
class GitPreferences {
    [string] $AutoLoadGitStatusMode = "None" # None | Favorites | All

    GitPreferences() {}
}
