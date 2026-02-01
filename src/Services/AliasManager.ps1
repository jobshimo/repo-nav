<#
.SYNOPSIS
    AliasManager - Manages repository aliases
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for alias management
    - DIP: Depends on UserPreferencesService (abstraction)
    - OCP: Can be extended with new alias features
#>

class AliasManager : IAliasManager {
    [IUserPreferencesService] $PreferencesService
    
    # Constructor with dependency injection
    AliasManager([IUserPreferencesService]$preferencesService) {
        $this.PreferencesService = $preferencesService
    }

    # Get all aliases as hashtable: RepoIdentifier -> AliasInfo
    [hashtable] GetAllAliases() {
        $prefs = $this.PreferencesService.LoadPreferences()
        if ($null -eq $prefs.Repository.PathAliases) {
            return @{}
        }
        
        $result = @{}
        $pathAliases = $prefs.Repository.PathAliases
        
        foreach ($key in $pathAliases.Keys) {
            $val = $pathAliases[$key]
            # Val is PathAlias object
            if ($val -is [PathAlias]) {
                $color = [ColorPalette]::GetColorOrDefault($val.Color)
                $aliasInfo = [AliasInfo]::new($val.Text, $color)
                $result[$key] = $aliasInfo
            }
        }
        
        return $result
    }
    
    # Get alias for a specific repository (by name or path)
    [AliasInfo] GetAlias([string]$repoIdentifier) {
        $aliases = $this.GetAllAliases()
        if ($aliases.ContainsKey($repoIdentifier)) {
            return $aliases[$repoIdentifier]
        }
        return $null
    }
    
    # Check if repository has an alias
    [bool] HasAlias([string]$repoIdentifier) {
        $aliases = $this.GetAllAliases()
        return $aliases.ContainsKey($repoIdentifier)
    }
    
    # Set alias for a repository
    [bool] SetAlias([string]$repoIdentifier, [AliasInfo]$aliasInfo) {
        if (-not $aliasInfo.IsValid()) {
            Write-Warning "Invalid alias format"
            return $false
        }
        
        $prefs = $this.PreferencesService.LoadPreferences()
        if ($null -eq $prefs.Repository.PathAliases) {
            $prefs.Repository.PathAliases = @{}
        }
        
        $newAlias = [PathAlias]::new($aliasInfo.Alias, $aliasInfo.Color)
        $prefs.Repository.PathAliases[$repoIdentifier] = $newAlias
        
        return $this.PreferencesService.SavePreferences($prefs)
    }
    
    # Remove alias for a repository
    [bool] RemoveAlias([string]$repoIdentifier) {
        $prefs = $this.PreferencesService.LoadPreferences()
        if ($null -ne $prefs.Repository.PathAliases -and $prefs.Repository.PathAliases.ContainsKey($repoIdentifier)) {
            $prefs.Repository.PathAliases.Remove($repoIdentifier)
            return $this.PreferencesService.SavePreferences($prefs)
        }
        return $false
    }

    # Check if alias name is already used (Required by IAliasManager)
    [bool] IsAliasNameTaken([string]$alias) {
        $aliases = $this.GetAllAliases()
        foreach ($info in $aliases.Values) {
            if ($info.Alias -eq $alias) {
                return $true
            }
        }
        return $false
    }
}
