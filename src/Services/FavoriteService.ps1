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
    
    # Check if a repository is marked as favorite
    [bool] IsFavorite([string]$repoPath) {
        [string[]]$favorites = $this.GetFavorites()
        return $favorites -contains $repoPath
    }
    
    # Add a repository to favorites
    [bool] AddFavorite([string]$repoPath) {
        if ([string]::IsNullOrWhiteSpace($repoPath)) {
            return $false
        }
        
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$currentFavorites = @($config.favorites)
        
        # Already a favorite
        if ($currentFavorites -contains $repoPath) {
            return $true
        }
        
        # Add and save
        $config.favorites = @($currentFavorites + $repoPath)
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    # Remove a repository from favorites
    [bool] RemoveFavorite([string]$repoPath) {
        $config = $this.ConfigService.LoadConfiguration()
        [string[]]$currentFavorites = @($config.favorites)
        
        # Not a favorite
        if ($currentFavorites -notcontains $repoPath) {
            return $true
        }
        
        # Remove and save
        $config.favorites = @($currentFavorites | Where-Object { $_ -ne $repoPath })
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    # Toggle favorite status
    [bool] ToggleFavorite([string]$repoPath) {
        if ($this.IsFavorite($repoPath)) {
            return $this.RemoveFavorite($repoPath)
        }
        else {
            return $this.AddFavorite($repoPath)
        }
    }
    
    # Get favorite count
    [int] GetFavoriteCount() {
        return $this.GetFavorites().Count
    }
    
    # Clear all favorites
    [bool] ClearAllFavorites() {
        $config = $this.ConfigService.LoadConfiguration()
        $config.favorites = @()
        return $this.ConfigService.SaveConfiguration($config)
    }
    
    # Update repository model with favorite status
    [void] UpdateRepositoryModel([RepositoryModel]$repository) {
        $repository.MarkAsFavorite($this.IsFavorite($repository.FullPath))
    }
    
    # Update multiple repository models
    [void] UpdateRepositoryModels([array]$repositories) {
        $favorites = $this.GetFavorites()
        foreach ($repo in $repositories) {
            $repo.MarkAsFavorite($favorites -contains $repo.FullPath)
        }
    }
}
