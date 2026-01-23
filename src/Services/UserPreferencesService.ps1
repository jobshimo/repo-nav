<#
.SYNOPSIS
    UserPreferencesService - Manages user preferences persistence
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for reading/writing user preferences JSON
    - DIP: Provides abstraction for preferences persistence
    - OCP: Can be extended for new preferences without modification
    
    This service manages the .repo-preferences.json file that contains:
    - UI preferences (favorites position, theme, etc.)
    - Display preferences
    - Behavior preferences
#>

class UserPreferencesService {
    [string] $PreferencesFilePath
    
    # Constructor
    UserPreferencesService() {
        $this.PreferencesFilePath = Join-Path ([Constants]::ScriptRoot) ".repo-preferences.json"
    }
    
    # Constructor with custom path (for testing)
    UserPreferencesService([string]$customPath) {
        $this.PreferencesFilePath = $customPath
    }
    
    # Load preferences from file
    [PSCustomObject] LoadPreferences() {
        if (-not (Test-Path $this.PreferencesFilePath)) {
            return $this.CreateDefaultPreferences()
        }
        
        try {
            $content = Get-Content $this.PreferencesFilePath -Raw -ErrorAction Stop
            $preferences = ConvertFrom-Json $content -ErrorAction Stop
            
            # Validate and normalize preferences
            $normalized = $this.NormalizePreferences($preferences)
            
            return $normalized
        }
        catch {
            Write-Warning "Error loading preferences file: $_"
            return $this.CreateDefaultPreferences()
        }
    }
    
    # Save preferences to file
    [bool] SavePreferences([PSCustomObject]$preferences) {
        try {
            $json = $preferences | ConvertTo-Json -Depth 10
            $json | Set-Content $this.PreferencesFilePath -Encoding UTF8 -ErrorAction Stop
            return $true
        }
        catch {
            Write-Error "Error saving preferences file: $_"
            return $false
        }
    }
    
    # Create default preferences structure
    [PSCustomObject] CreateDefaultPreferences() {
        $defaults = [PSCustomObject]@{
            display = [PSCustomObject]@{
                favoritesOnTop = $true
            }
        }
        
        # Save defaults to file
        $this.SavePreferences($defaults)
        
        return $defaults
    }
    
    # Normalize preferences to ensure all required fields exist
    [PSCustomObject] NormalizePreferences([PSCustomObject]$preferences) {
        # Ensure display section exists
        if (-not ($preferences.PSObject.Properties.Name -contains 'display')) {
            $preferences | Add-Member -NotePropertyName 'display' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        # Ensure favoritesOnTop exists with default value
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'favoritesOnTop')) {
            $preferences.display | Add-Member -NotePropertyName 'favoritesOnTop' -NotePropertyValue $true -Force
        }
        
        # Ensure it's a boolean
        if ($preferences.display.favoritesOnTop -isnot [bool]) {
            $preferences.display.favoritesOnTop = [bool]$preferences.display.favoritesOnTop
        }
        
        return $preferences
    }
    
    # Check if preferences file exists
    [bool] PreferencesExists() {
        return Test-Path $this.PreferencesFilePath
    }
    
    # Get specific preference value
    [object] GetPreference([string]$section, [string]$key) {
        $preferences = $this.LoadPreferences()
        
        if ($preferences.PSObject.Properties.Name -contains $section) {
            $sectionObj = $preferences.$section
            if ($sectionObj.PSObject.Properties.Name -contains $key) {
                return $sectionObj.$key
            }
        }
        
        return $null
    }
    
    # Set specific preference value
    [bool] SetPreference([string]$section, [string]$key, [object]$value) {
        $preferences = $this.LoadPreferences()
        
        # Ensure section exists
        if (-not ($preferences.PSObject.Properties.Name -contains $section)) {
            $preferences | Add-Member -NotePropertyName $section -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        # Set value
        if ($preferences.$section.PSObject.Properties.Name -contains $key) {
            $preferences.$section.$key = $value
        } else {
            $preferences.$section | Add-Member -NotePropertyName $key -NotePropertyValue $value -Force
        }
        
        return $this.SavePreferences($preferences)
    }
    
    # Toggle a boolean preference
    [bool] TogglePreference([string]$section, [string]$key) {
        $currentValue = $this.GetPreference($section, $key)
        
        if ($currentValue -is [bool]) {
            return $this.SetPreference($section, $key, -not $currentValue)
        }
        
        return $false
    }
}
