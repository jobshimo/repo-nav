<#
.SYNOPSIS
    UserPreferences - Master container for all user preferences
    
.DESCRIPTION
    Replaces loose PSCustomObject structure with strong typing.
    Serialized directly to JSON.
#>
class UserPreferences {
    [GeneralPreferences] $General
    [DisplayPreferences] $Display
    [GitPreferences] $Git
    [HiddenPreferences] $Hidden
    [RepositoryPreferences] $Repository

    UserPreferences() {
        $this.General = [GeneralPreferences]::new()
        $this.Display = [DisplayPreferences]::new()
        $this.Git = [GitPreferences]::new()
        $this.Hidden = [HiddenPreferences]::new()
        $this.Repository = [RepositoryPreferences]::new()
    }
}
