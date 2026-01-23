<#
.SYNOPSIS
    AliasInfo - Encapsulates alias information for a repository
    
.DESCRIPTION
    Following SRP (Single Responsibility Principle):
    This class ONLY holds alias data (name and color).
    Pure Data Transfer Object (DTO).
#>

class AliasInfo {
    [string] $Alias
    [string] $Color
    
    # Constructor with parameters
    AliasInfo([string]$alias, [string]$color) {
        $this.Alias = $alias
        # Validate and set color (use default if invalid)
        $this.Color = [ColorPalette]::GetColorOrDefault($color)
    }
    
    # Constructor with default color
    AliasInfo([string]$alias) {
        $this.Alias = $alias
        $this.Color = [ColorPalette]::DefaultAliasColor
    }
    
    # Validate alias format (no spaces)
    [bool] IsValid() {
        return -not [string]::IsNullOrWhiteSpace($this.Alias) -and 
               $this.Alias -notmatch '\s'
    }
    
    # ToString for debugging
    [string] ToString() {
        return "$($this.Alias) [$($this.Color)]"
    }
}
