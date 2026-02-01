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

class UserPreferencesService : IUserPreferencesService {
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
    [UserPreferences] LoadPreferences() {
        if (-not (Test-Path $this.PreferencesFilePath)) {
            return $this.CreateDefaultPreferences()
        }
        
        try {
            $item = Get-Item $this.PreferencesFilePath -ErrorAction Stop
            if ($item.Length -eq 0) {
                return $this.CreateDefaultPreferences()
            }
            
            $content = Get-Content $this.PreferencesFilePath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($content)) {
                return $this.CreateDefaultPreferences()
            }

            # First deserialize to PSCustomObject (what ConvertFrom-Json returns)
            $jsonObj = ConvertFrom-Json $content -ErrorAction Stop
            
            # Then map to our strong types
            return $this.MapToUserPreferences($jsonObj)
        }
        catch {
            Write-Warning "Error loading preferences file: $_"
            return $this.CreateDefaultPreferences()
        }
    }
    
    # Save preferences to file
    [bool] SavePreferences([UserPreferences]$preferences) {
        try {
            # Convert to JSON directly - strong types serialize cleanly
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
    [UserPreferences] CreateDefaultPreferences() {
        return [UserPreferences]::new()
    }
    
    # Map dynamic JSON object to strong types
    hidden [UserPreferences] MapToUserPreferences([PSCustomObject]$json) {
        $prefs = [UserPreferences]::new()
        
        # General
        if ($json.PSObject.Properties.Match('general').Count) {
            if ($json.general.PSObject.Properties.Match('language').Count) { $prefs.General.Language = $json.general.language }
            if ($json.general.PSObject.Properties.Match('debugMode').Count) { $prefs.General.DebugMode = $json.general.debugMode }
        }

        # Display
        if ($json.PSObject.Properties.Match('display').Count) {
             $d = $json.display
             if ($d.PSObject.Properties.Match('favoritesOnTop').Count) { $prefs.Display.FavoritesOnTop = [bool]$d.favoritesOnTop }
             if ($d.PSObject.Properties.Match('selectedBackground').Count) { $prefs.Display.SelectedBackground = $d.selectedBackground }
             if ($d.PSObject.Properties.Match('selectedDelimiter').Count) { $prefs.Display.SelectedDelimiter = $d.selectedDelimiter }
             if ($d.PSObject.Properties.Match('aliasPosition').Count) { $prefs.Display.AliasPosition = $d.aliasPosition }
             if ($d.PSObject.Properties.Match('aliasSeparator').Count) { $prefs.Display.AliasSeparator = $d.aliasSeparator }
             if ($d.PSObject.Properties.Match('aliasWrapper').Count) { $prefs.Display.AliasWrapper = $d.aliasWrapper }
             if ($d.PSObject.Properties.Match('menuMode').Count) { $prefs.Display.MenuMode = $d.menuMode }
             if ($d.PSObject.Properties.Match('pathDisplayMode').Count) { $prefs.Display.PathDisplayMode = $d.pathDisplayMode }
             
             if ($d.PSObject.Properties.Match('menuSections').Count) {
                $ms = $d.menuSections
                if ($ms.PSObject.Properties.Match('navigation').Count) { $prefs.Display.MenuSections.Navigation = [bool]$ms.navigation }
                if ($ms.PSObject.Properties.Match('alias').Count) { $prefs.Display.MenuSections.Alias = [bool]$ms.alias }
                if ($ms.PSObject.Properties.Match('modules').Count) { $prefs.Display.MenuSections.Modules = [bool]$ms.modules }
                if ($ms.PSObject.Properties.Match('repository').Count) { $prefs.Display.MenuSections.Repository = [bool]$ms.repository }
                if ($ms.PSObject.Properties.Match('paths').Count) { $prefs.Display.MenuSections.Paths = [bool]$ms.paths }
                if ($ms.PSObject.Properties.Match('git').Count) { $prefs.Display.MenuSections.Git = [bool]$ms.git }
                if ($ms.PSObject.Properties.Match('tools').Count) { $prefs.Display.MenuSections.Tools = [bool]$ms.tools }
             }
        }
        
        # Git
        if ($json.PSObject.Properties.Match('git').Count) {
            # Migration logic
            if ($json.git.PSObject.Properties.Match('autoLoadFavoritesStatus').Count -and 
                -not $json.git.PSObject.Properties.Match('autoLoadGitStatusMode').Count) {
                $oldVal = [bool]$json.git.autoLoadFavoritesStatus
                $prefs.Git.AutoLoadGitStatusMode = if ($oldVal) { "Favorites" } else { "None" }
            }
            elseif ($json.git.PSObject.Properties.Match('autoLoadGitStatusMode').Count) {
                $prefs.Git.AutoLoadGitStatusMode = $json.git.autoLoadGitStatusMode
            }
        }
        
        # Hidden
        if ($json.PSObject.Properties.Match('hidden').Count) {
            if ($json.hidden.PSObject.Properties.Match('hiddenRepos').Count) {
                # Ensure array
                $raw = $json.hidden.hiddenRepos
                if ($raw -is [Array]) { $prefs.Hidden.HiddenRepos = $raw }
                elseif ($null -ne $raw) { $prefs.Hidden.HiddenRepos = @($raw) }
            }
        }
        
        # Repository
        if ($json.PSObject.Properties.Match('repository').Count) {
            $r = $json.repository
            if ($r.PSObject.Properties.Match('defaultPath').Count) { $prefs.Repository.DefaultPath = $r.defaultPath }
            
            if ($r.PSObject.Properties.Match('paths').Count) {
                 $raw = $r.paths
                 if ($raw -is [Array]) { $prefs.Repository.Paths = $raw }
                 elseif ($null -ne $raw) { $prefs.Repository.Paths = @($raw) }
            }
            
            if ($r.PSObject.Properties.Match('pathAliases').Count) {
                if ($r.pathAliases -is [PSCustomObject] -or $r.pathAliases -is [Hashtable]) {
                    # Convert to hashtable of PathAlias
                    $prefs.Repository.PathAliases = @{}
                    $r.pathAliases.PSObject.Properties | ForEach-Object {
                        $val = $_.Value
                        if ($val -is [string]) {
                            # Legacy string alias
                            $prefs.Repository.PathAliases[$_.Name] = [PathAlias]::new($val, "Default")
                        } elseif ($val.PSObject.Properties.Match('Text').Count) {
                             $color = if ($val.PSObject.Properties.Match('Color').Count) { $val.Color } else { "Default" }
                             $prefs.Repository.PathAliases[$_.Name] = [PathAlias]::new($val.Text, $color)
                        }
                    }
                }
            }
            
            if ($r.PSObject.Properties.Match('favorites').Count) {
                 $raw = $r.favorites
                 if ($raw -is [Array]) { $prefs.Repository.Favorites = $raw }
                 elseif ($null -ne $raw) { $prefs.Repository.Favorites = @($raw) }
            }
        }

        return $prefs
    }
    
    # Check if preferences file exists
    [bool] PreferencesExists() {
        return Test-Path $this.PreferencesFilePath
    }
    
    # Get specific preference value using reflection/dynamic access is trickier with strong types
    # So we'll impl a robust way or simplify. For now, matching previous logic but safer.
    [object] GetPreference([string]$section, [string]$key) {
        $preferences = $this.LoadPreferences()
        
        # Use reflection to get property
        $sectionProp = $preferences.GetType().GetProperty($section, [System.Reflection.BindingFlags]'IgnoreCase,Public,Instance')
        if ($null -ne $sectionProp) {
            $sectionObj = $sectionProp.GetValue($preferences)
            $keyProp = $sectionObj.GetType().GetProperty($key, [System.Reflection.BindingFlags]'IgnoreCase,Public,Instance')
            if ($null -ne $keyProp) {
                return $keyProp.GetValue($sectionObj)
            }
        }
        
        return $null
    }
    
    # Set specific preference value
    [bool] SetPreference([string]$section, [string]$key, [object]$value) {
        $preferences = $this.LoadPreferences()
        
        $sectionProp = $preferences.GetType().GetProperty($section, [System.Reflection.BindingFlags]'IgnoreCase,Public,Instance')
        if ($null -eq $sectionProp) { return $false }
        
        $sectionObj = $sectionProp.GetValue($preferences)
        $keyProp = $sectionObj.GetType().GetProperty($key, [System.Reflection.BindingFlags]'IgnoreCase,Public,Instance')
        
        if ($null -ne $keyProp) {
            try {
                # Convert value if needed
                $targetType = $keyProp.PropertyType
                $convertedValue = $value
                if ($targetType -eq [bool] -and $value -isnot [bool]) {
                     $convertedValue = [bool]$value
                }
                
                $keyProp.SetValue($sectionObj, $convertedValue)
                return $this.SavePreferences($preferences)
            }
            catch {
                Write-Error "Failed to set preference $section.$key : $_"
                return $false
            }
        }
        
        return $false
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
        
        try {
             $fullPath = (Resolve-Path $path).Path
             
             # Use generic list for easier manipulation if needed, or simple array addition
             if ($preferences.Repository.Paths -notcontains $fullPath) {
                 # Create new array manually to ensure distinct
                 $newPaths = [System.Collections.Generic.List[string]]::new($preferences.Repository.Paths)
                 $newPaths.Add($fullPath)
                 $preferences.Repository.Paths = $newPaths.ToArray()
                 
                 $this.SavePreferences($preferences) | Out-Null
             }
        } catch {
            $logger = [ServiceRegistry]::Resolve('LoggerService')
            if ($null -ne $logger) { $logger.LogError($_) }
        }
    }
}
