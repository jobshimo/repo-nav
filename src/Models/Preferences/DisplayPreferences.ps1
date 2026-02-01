<#
.SYNOPSIS
    DisplayPreferences - Strongly typed model for display settings
#>
class DisplayPreferences {
    [bool] $ShowHeaders = $true
    [bool] $FavoritesOnTop = $true
    [string] $SelectedBackground = "DarkGray"
    [string] $SelectedDelimiter = "None"
    [string] $AliasPosition = "After"       # After | Before
    [string] $AliasSeparator = " - "        # " - " | " : " | " | " | "None"
    [string] $AliasWrapper = "None"         # None | Parens | Brackets | Braces
    [string] $MenuMode = "Full"             # Full | Minimal | Hidden | Custom
    [string] $PathDisplayMode = "Path"      # Path | Alias | Both
    [MenuSectionsPreferences] $MenuSections

    DisplayPreferences() {
        $this.MenuSections = [MenuSectionsPreferences]::new()
    }
}
