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

class AliasManager {
    [ConfigurationService] $ConfigService
    
    # Constructor with dependency injection
    AliasManager([ConfigurationService]$configService) {
        $this.ConfigService = $configService
    }
    
    # Get all aliases as hashtable: RepoName -> AliasInfo
    [hashtable] GetAllAliases() {
        $config = $this.ConfigService.LoadConfiguration()
        $result = @{}
        
        if ($config.aliases) {
            foreach ($property in $config.aliases.PSObject.Properties) {
                $repoName = $property.Name
                $aliasData = $property.Value
                
                # Handle old format (string) vs new format (object)
                if ($aliasData -is [string]) {
                    $result[$repoName] = [AliasInfo]::new($aliasData)
                }
                else {
                    $alias = $aliasData.alias
                    $color = if ($aliasData.color) { $aliasData.color } else { [ColorPalette]::DefaultAliasColor }
                    $result[$repoName] = [AliasInfo]::new($alias, $color)
                }
            }
        }
        
        return $result
    }
    
    # Get alias for a specific repository
    [AliasInfo] GetAlias([string]$repoName) {
        $aliases = $this.GetAllAliases()
        if ($aliases.ContainsKey($repoName)) {
            return $aliases[$repoName]
        }
        return $null
    }
    
    # Check if repository has an alias
    [bool] HasAlias([string]$repoName) {
        $aliases = $this.GetAllAliases()
        return $aliases.ContainsKey($repoName)
    }
    
    # Set alias for a repository
    [bool] SetAlias([string]$repoName, [AliasInfo]$aliasInfo) {
        if (-not $aliasInfo.IsValid()) {
            Write-Warning "Invalid alias format"
            return $false
        }
        
        $config = $this.ConfigService.LoadConfiguration()
        
        # Create alias object
        $aliasData = [PSCustomObject]@{
            alias = $aliasInfo.Alias
            color = $aliasInfo.Color
        }
        
        # Add or update alias
        if ($config.aliases.PSObject.Properties.Name -contains $repoName) {
            $config.aliases.$repoName = $aliasData
        }
        else {
            $config.aliases | Add-Member -NotePropertyName $repoName -NotePropertyValue $aliasData
        }
        
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    # Remove alias for a repository
    [bool] RemoveAlias([string]$repoName) {
        $config = $this.ConfigService.LoadConfiguration()
        
        if ($config.aliases.PSObject.Properties.Name -contains $repoName) {
            $config.aliases.PSObject.Properties.Remove($repoName)
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
