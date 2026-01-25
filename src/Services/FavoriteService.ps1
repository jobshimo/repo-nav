<#
.SYNOPSIS
    FavoriteService - Manages repository favorites
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for favorite management
    - DIP: Depends on ConfigurationService abstraction
    - OCP: Can be extended for new favorite features (groups, tags, etc.)
    
    Extracted from AliasManager to separate favorite concerns from alias concerns.
    
.NOTES
    This service delegates persistence to ConfigurationService and provides
    a clean API for favorite operations.
#>

class FavoriteService {
    # Dependencies
    [ConfigurationService] $ConfigService
    
    # Constructor with dependency injection
    FavoriteService([ConfigurationService]$configService) {
        $this.ConfigService = $configService
    }
    
    <#
    .SYNOPSIS
        Gets all favorite repository names
        
    .RETURNS
        Array of repository names marked as favorites
    #>
    [string[]] GetFavorites() {
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$favorites = @($config.favorites)
        return $favorites
    }
    
    <#
    .SYNOPSIS
        Checks if a repository is marked as favorite
        
    .PARAMETER repoName
        The repository name to check
        
    .RETURNS
        True if the repository is a favorite
    #>
    [bool] IsFavorite([string]$repoName) {
        [string[]]$favorites = $this.GetFavorites()
        return $favorites -contains $repoName
    }
    
    <#
    .SYNOPSIS
        Adds a repository to favorites
        
    .PARAMETER repoName
        The repository name to add
        
    .RETURNS
        True if successfully added (or already exists)
    #>
    [bool] AddFavorite([string]$repoName) {
        if ([string]::IsNullOrWhiteSpace($repoName)) {
            return $false
        }
        
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$currentFavorites = @($config.favorites)
        
        # Already a favorite
        if ($currentFavorites -contains $repoName) {
            return $true
        }
        
        # Add and save
        $config.favorites = @($currentFavorites + $repoName)
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    <#
    .SYNOPSIS
        Removes a repository from favorites
        
    .PARAMETER repoName
        The repository name to remove
        
    .RETURNS
        True if successfully removed (or didn't exist)
    #>
    [bool] RemoveFavorite([string]$repoName) {
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$currentFavorites = @($config.favorites)
        
        # Not a favorite
        if ($currentFavorites -notcontains $repoName) {
            return $true
        }
        
        # Remove and save
        $config.favorites = @($currentFavorites | Where-Object { $_ -ne $repoName })
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    <#
    .SYNOPSIS
        Toggles the favorite status of a repository
        
    .PARAMETER repoName
        The repository name to toggle
        
    .RETURNS
        True if operation succeeded
    #>
    [bool] ToggleFavorite([string]$repoName) {
        if ($this.IsFavorite($repoName)) {
            return $this.RemoveFavorite($repoName)
        }
        else {
            return $this.AddFavorite($repoName)
        }
    }
    
    <#
    .SYNOPSIS
        Gets the count of favorites
        
    .RETURNS
        Number of favorite repositories
    #>
    [int] GetFavoriteCount() {
        return $this.GetFavorites().Count
    }
    
    <#
    .SYNOPSIS
        Clears all favorites
        
    .RETURNS
        True if successfully cleared
    #>
    [bool] ClearAllFavorites() {
        $config = $this.ConfigService.LoadConfiguration()
        $config.favorites = @()
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    <#
    .SYNOPSIS
        Updates repository model with favorite status
        
    .PARAMETER repository
        The RepositoryModel to update
    #>
    [void] UpdateRepositoryModel([RepositoryModel]$repository) {
        $repository.MarkAsFavorite($this.IsFavorite($repository.Name))
    }
    
    <#
    .SYNOPSIS
        Updates multiple repository models with favorite status
        
    .PARAMETER repositories
        Array of RepositoryModel objects to update
    #>
    [void] UpdateRepositoryModels([array]$repositories) {
        $favorites = $this.GetFavorites()
        foreach ($repo in $repositories) {
            $repo.MarkAsFavorite($favorites -contains $repo.Name)
        }
    }
}
