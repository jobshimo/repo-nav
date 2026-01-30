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
            hidden = [PSCustomObject]@{
                hiddenRepos = @()
            }
            general = [PSCustomObject]@{
                language = "en"
            }
            display = [PSCustomObject]@{
                favoritesOnTop = $true
                selectedBackground = "DarkGray"
                selectedDelimiter = "None"
                aliasPosition = "After" # After | Before
                aliasSeparator = " - "  # " - " | " : " | " | " | "None"
                aliasWrapper = "None"   # None | Parens | Brackets | Braces
                menuMode = "Full" # Full | Minimal | Hidden | Custom
                menuSections = [PSCustomObject]@{
                    navigation = $true
                    alias = $true
                    modules = $true
                    repository = $true
                    git = $true
                    tools = $true
                }
            }
            git = [PSCustomObject]@{
                autoLoadGitStatusMode = "None" # None | Favorites | All
            }
        }
        
        $this.SavePreferences($defaults)
        
        return $defaults
    }
    
    # Normalize preferences to ensure all required fields exist
    [PSCustomObject] NormalizePreferences([PSCustomObject]$preferences) {
        # General Section
        if (-not ($preferences.PSObject.Properties.Name -contains 'general')) {
            $preferences | Add-Member -NotePropertyName 'general' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        if (-not ($preferences.general.PSObject.Properties.Name -contains 'language')) {
            $preferences.general | Add-Member -NotePropertyName 'language' -NotePropertyValue "en" -Force
        }

        # Display Section
        if (-not ($preferences.PSObject.Properties.Name -contains 'display')) {
            $preferences | Add-Member -NotePropertyName 'display' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'favoritesOnTop')) {
            $preferences.display | Add-Member -NotePropertyName 'favoritesOnTop' -NotePropertyValue $true -Force
        }
        
        if ($preferences.display.favoritesOnTop -isnot [bool]) {
            $preferences.display.favoritesOnTop = [bool]$preferences.display.favoritesOnTop
        }
        
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'selectedBackground')) {
            $preferences.display | Add-Member -NotePropertyName 'selectedBackground' -NotePropertyValue "DarkGray" -Force
        }
        
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'selectedDelimiter')) {
            $preferences.display | Add-Member -NotePropertyName 'selectedDelimiter' -NotePropertyValue "None" -Force
        }
        
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'aliasPosition')) {
            $preferences.display | Add-Member -NotePropertyName 'aliasPosition' -NotePropertyValue "After" -Force
        }
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'aliasSeparator')) {
            $preferences.display | Add-Member -NotePropertyName 'aliasSeparator' -NotePropertyValue " - " -Force
        }
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'aliasWrapper')) {
            $preferences.display | Add-Member -NotePropertyName 'aliasWrapper' -NotePropertyValue "None" -Force
        }
        
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'pathDisplayMode')) {
            $preferences.display | Add-Member -NotePropertyName 'pathDisplayMode' -NotePropertyValue "Path" -Force
        }

        if (-not ($preferences.display.PSObject.Properties.Name -contains 'menuMode')) {
            $preferences.display | Add-Member -NotePropertyName 'menuMode' -NotePropertyValue "Full" -Force
        }
        
        if (-not ($preferences.display.PSObject.Properties.Name -contains 'menuSections')) {
            $menuSections = [PSCustomObject]@{
                navigation = $true
                alias = $true
                modules = $true
                repository = $true
                paths = $true
                git = $true
                tools = $true
            }
            $preferences.display | Add-Member -NotePropertyName 'menuSections' -NotePropertyValue $menuSections -Force
        }
        else {
            # Normalize menuSections
            $sections = $preferences.display.menuSections
            if (-not ($sections.PSObject.Properties.Name -contains 'navigation')) { $sections | Add-Member -NotePropertyName 'navigation' -NotePropertyValue $true -Force }
            if (-not ($sections.PSObject.Properties.Name -contains 'alias')) { $sections | Add-Member -NotePropertyName 'alias' -NotePropertyValue $true -Force }
            if (-not ($sections.PSObject.Properties.Name -contains 'modules')) { $sections | Add-Member -NotePropertyName 'modules' -NotePropertyValue $true -Force }
            if (-not ($sections.PSObject.Properties.Name -contains 'repository')) { $sections | Add-Member -NotePropertyName 'repository' -NotePropertyValue $true -Force }
            if (-not ($sections.PSObject.Properties.Name -contains 'paths')) { $sections | Add-Member -NotePropertyName 'paths' -NotePropertyValue $true -Force }
            if (-not ($sections.PSObject.Properties.Name -contains 'git')) { $sections | Add-Member -NotePropertyName 'git' -NotePropertyValue $true -Force }
            if (-not ($sections.PSObject.Properties.Name -contains 'tools')) { $sections | Add-Member -NotePropertyName 'tools' -NotePropertyValue $true -Force }
        }

        if (-not ($preferences.PSObject.Properties.Name -contains 'git')) {
            $preferences | Add-Member -NotePropertyName 'git' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        # Backward compatibility / Migration
        if ($preferences.git.PSObject.Properties.Name -contains 'autoLoadFavoritesStatus' -and 
            -not ($preferences.git.PSObject.Properties.Name -contains 'autoLoadGitStatusMode')) {
            
            $oldVal = [bool]$preferences.git.autoLoadFavoritesStatus
            $mode = if ($oldVal) { "Favorites" } else { "None" }
            $preferences.git | Add-Member -NotePropertyName 'autoLoadGitStatusMode' -NotePropertyValue $mode -Force
        }
        
        if (-not ($preferences.git.PSObject.Properties.Name -contains 'autoLoadGitStatusMode')) {
            $preferences.git | Add-Member -NotePropertyName 'autoLoadGitStatusMode' -NotePropertyValue "None" -Force
        }
        
        # Hidden Section
        if (-not ($preferences.PSObject.Properties.Name -contains 'hidden')) {
            $preferences | Add-Member -NotePropertyName 'hidden' -NotePropertyValue ([PSCustomObject]@{
                hiddenRepos = @()
            }) -Force
        }
        
        # defaultVisibility removed
        
        if (-not ($preferences.hidden.PSObject.Properties.Name -contains 'hiddenRepos')) {
            $preferences.hidden | Add-Member -NotePropertyName 'hiddenRepos' -NotePropertyValue @() -Force
        }
        
        if (-not ($preferences.hidden.PSObject.Properties.Name -contains 'hiddenRepos')) {
            $preferences.hidden | Add-Member -NotePropertyName 'hiddenRepos' -NotePropertyValue @() -Force
        }

        # Repository Section
        if (-not ($preferences.PSObject.Properties.Name -contains 'repository')) {
            $preferences | Add-Member -NotePropertyName 'repository' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        
        if (-not ($preferences.repository.PSObject.Properties.Name -contains 'paths')) {
            $preferences.repository | Add-Member -NotePropertyName 'paths' -NotePropertyValue @() -Force
        }
        
        if (-not ($preferences.repository.PSObject.Properties.Name -contains 'pathAliases')) {
            $preferences.repository | Add-Member -NotePropertyName 'pathAliases' -NotePropertyValue ([PSCustomObject]@{}) -Force
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

    # Ensure a path exists in preferences
    [void] EnsurePathInPreferences([string]$path) {
        if ([string]::IsNullOrWhiteSpace($path)) { return }
        
        $preferences = $this.LoadPreferences()
        $currentPaths = if ($preferences.repository.paths) { [array]$preferences.repository.paths } else { @() }
        
        # Normalize
        try {
             $fullPath = (Resolve-Path $path).Path
             if ($currentPaths -notcontains $fullPath) {
                 $currentPaths += $fullPath
                 $this.SetPreference("repository", "paths", $currentPaths)
             }
        } catch {}
    }
}
