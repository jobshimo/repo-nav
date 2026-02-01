<#
.SYNOPSIS
    AliasManager - Manages repository aliases and favorites
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for alias and favorite management
    - DIP: Depends on ConfigurationService (abstraction) not implementation
    - OCP: Can be extended with new alias features
    
    This class provides high-level operations for:
    - Setting/removing aliases
    - Managing favorites
    - Querying alias information
#>

class AliasManager : IAliasManager {
    [IConfigurationService] $ConfigService
    
    # Constructor with dependency injection
    AliasManager([IConfigurationService]$configService) {
        $this.ConfigService = $configService
    }
    
    # Helper to normalize aliases configuration to a List
    hidden [System.Collections.ArrayList] GetAliasesAsList([PSCustomObject]$config) {
        $list = [System.Collections.ArrayList]::new()
        
        if ($null -eq $config.aliases) {
            return $list
        }

        # Check if it's a Hashtable/PSCustomObject
        if ($config.aliases -is [PSCustomObject] -or $config.aliases -is [hashtable]) {
            # AMBIGUITY CHECK: Is this a legacy MAP or a single ITEM from a simplified JSON array?
            $hasAliasProp = if ($config.aliases -is [hashtable]) { $config.aliases.ContainsKey('alias') } else { $null -ne $config.aliases.PSObject.Properties['alias'] }
            
            if ($hasAliasProp) {
                # This is a SINGLE ITEM (New format), not a Map
                [void]$list.Add($config.aliases)
            } else {
                # This is a LEGACY MAP
                foreach ($property in $config.aliases.PSObject.Properties) {
                    $aliasData = $property.Value
                    $key = $property.Name
                    
                    # Determine if key is path or name based on content
                    $isPath = $key.Contains("\") -or $key.Contains("/")
                    
                    # Normalize data structure
                    $entry = $null
                    
                    # Handle simple string format "alias" (Legacy)
                    if ($aliasData -is [string]) {
                        $entry = [PSCustomObject]@{
                            alias = $aliasData
                            color = [ColorPalette]::DefaultAliasColor
                        }
                    } else {
                        $entry = [PSCustomObject]@{
                            alias = $aliasData.alias
                            color = if ($aliasData.color) { $aliasData.color } else { [ColorPalette]::DefaultAliasColor }
                        }
                    }
                    
                    # Add identifier
                    if ($isPath) {
                        $entry | Add-Member -NotePropertyName "path" -NotePropertyValue $key -Force
                    } else {
                        $entry | Add-Member -NotePropertyName "name" -NotePropertyValue $key -Force
                    }
                    
                    [void]$list.Add($entry)
                }
            }
        }
        # Check if it's already an array or single object (New list format)
        else {
            $aliasArray = [ArrayHelper]::EnsureArray($config.aliases)
            if ($aliasArray.Count -gt 0) {
                $list.AddRange($aliasArray)
            }
        }
        
        return $list
    }

    # Get all aliases as hashtable: RepoIdentifier -> AliasInfo
    [hashtable] GetAllAliases() {
        $config = $this.ConfigService.LoadConfiguration()
        $aliasList = $this.GetAliasesAsList($config)
        $result = @{}
        
        foreach ($item in $aliasList) {
            $alias = $item.alias
            # Validate color
            $color = [ColorPalette]::GetColorOrDefault($item.color)
            $aliasInfo = [AliasInfo]::new($alias, $color)
            
            # Map by path if available
            if ($item.path) {
                $result[$item.path] = $aliasInfo
            }
            
            # Map by name if available (Legacy/Support)
            if ($item.name) {
                 $result[$item.name] = $aliasInfo
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
        
        $config = $this.ConfigService.LoadConfiguration()
        $aliasList = $this.GetAliasesAsList($config)
        
        # Prepare new list excluding existing entry for this path
        $updatedList = [System.Collections.ArrayList]::new()
        
        foreach ($item in $aliasList) {
            # If item has path and matches, skip (we will replace it)
            if ($item.PSObject.Properties.Name -contains 'path' -and $item.path -eq $repoIdentifier) {
                continue
            }
            [void]$updatedList.Add($item)
        }
        
        # Add new entry
        # We assume if SetAlias is called with a path-like string (with slashes), it's a path
        # If it's a simple name, should we store it as 'name'?
        # Based on user request, new entries should use 'path' property if needed.
        # Since RepositoryManager is sending FullPath, we treat it as path.
        
        $isPath = $repoIdentifier.Contains("\") -or $repoIdentifier.Contains("/")
        
        $newEntry = [PSCustomObject]@{
            alias = $aliasInfo.Alias
            color = $aliasInfo.Color
        }
        
        if ($isPath) {
             $newEntry | Add-Member -NotePropertyName "path" -NotePropertyValue $repoIdentifier
        } else {
             $newEntry | Add-Member -NotePropertyName "name" -NotePropertyValue $repoIdentifier
        }
        
        [void]$updatedList.Add($newEntry)
        
        $config.aliases = $updatedList
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    # Remove alias for a repository
    [bool] RemoveAlias([string]$repoIdentifier) {
        $config = $this.ConfigService.LoadConfiguration()
        $aliasList = $this.GetAliasesAsList($config)
        
        $updatedList = [System.Collections.ArrayList]::new()
        $found = $false
        
        foreach ($item in $aliasList) {
            # Check for path match
            if ($item.PSObject.Properties.Name -contains 'path' -and $item.path -eq $repoIdentifier) {
                $found = $true
                continue
            }
            # Check for name match (Legacy support for simple names)
            if ($item.PSObject.Properties.Name -contains 'name' -and $item.name -eq $repoIdentifier) {
                $found = $true
                continue
            }
            
            [void]$updatedList.Add($item)
        }
        
        if ($found) {
            $config.aliases = $updatedList
            return $this.ConfigService.SaveConfiguration($config)
        }
        
        return $false
    }
    
    # Get all favorites
    [string[]] GetFavorites() {
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$favorites = @($config.favorites)
        return $favorites
    }
    
    # Check if repository is favorite
    [bool] IsFavorite([string]$repoName) {
        [string[]]$favorites = $this.GetFavorites()
        return $favorites -contains $repoName
    }
    
    # Add repository to favorites
    [bool] AddFavorite([string]$repoName) {
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$currentFavorites = @($config.favorites)
        
        if ($currentFavorites -notcontains $repoName) {
            $config.favorites = @($currentFavorites + $repoName)
            return $this.ConfigService.SaveConfiguration($config)
        }
        
        return $false
    }
    
    # Remove repository from favorites
    [bool] RemoveFavorite([string]$repoName) {
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$currentFavorites = @($config.favorites)
        
        if ($currentFavorites -contains $repoName) {
            $config.favorites = @($currentFavorites | Where-Object { $_ -ne $repoName })
            return $this.ConfigService.SaveConfiguration($config)
        }
        
        return $false
    }
    
    # Toggle favorite status
    [bool] ToggleFavorite([string]$repoName) {
        if ($this.IsFavorite($repoName)) {
            return $this.RemoveFavorite($repoName)
        }
        else {
            return $this.AddFavorite($repoName)
        }
    }
}
