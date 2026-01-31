<#
.SYNOPSIS
    SelectionOptions - Configuration object for OptionSelector
    
.DESCRIPTION
    Replaces multiple parameters with a single typed configuration object.
    All properties have sensible defaults to avoid parameter ordering issues.
    
    Following SOLID principles:
    - SRP: Only contains configuration data
    - OCP: Easy to extend with new options without breaking existing code
#>

class SelectionOptions {
    # Required
    [string] $Title = ""
    [array] $Options = @()
    
    # Optional with sensible defaults
    [object] $CurrentValue = $null
    [string] $CancelText = "Cancel"
    [bool] $ShowCurrentMarker = $true
    [string] $Description = ""
    [ConsoleColor] $DescriptionColor = [ConsoleColor]::Yellow
    [bool] $ClearScreen = $true
    
    # Advanced: Callbacks
    [scriptblock] $OnSelectionChanged = $null
    [scriptblock] $OnRenderItem = $null
    
    # Factory method for simple Yes/No
    static [SelectionOptions] YesNo([string]$title, [string]$description) {
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Description = $description
        $config.ShowCurrentMarker = $false
        $config.Options = @(
            @{ DisplayText = "Yes"; Value = $true },
            @{ DisplayText = "No"; Value = $false }
        )
        return $config
    }
    
    # Factory method for simple selection
    static [SelectionOptions] Simple([string]$title, [array]$options) {
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Options = $options
        return $config
    }
}
