<#
.SYNOPSIS
    FavoriteService - Manages repository favorites
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for favorite management
    - DIP: Depends on UserPreferencesService abstraction
    - OCP: Can be extended for new favorite features
#>

class FavoriteService : IFavoriteService {
    # Dependencies
    [IUserPreferencesService] $PreferencesService
    
    # Constructor with dependency injection
    FavoriteService([IUserPreferencesService]$preferencesService) {
        $this.PreferencesService = $preferencesService
    }
    
    # Gets all favorite repository names
    [string[]] GetFavorites() {
        $prefs = $this.PreferencesService.LoadPreferences()
        return [ArrayHelper]::EnsureArray($prefs.Repository.Favorites)
    }
    
    # Check if a repository is marked as favorite
    [bool] IsFavorite([string]$repoPath) {
        $favorites = $this.GetFavorites()
        return $favorites -contains $repoPath
    }
    
    # Add a repository to favorites
    [bool] AddFavorite([string]$repoPath) {
        if ([string]::IsNullOrWhiteSpace($repoPath)) {
            return $false
        }
        
        $prefs = $this.PreferencesService.LoadPreferences()
        $currentFavs = [string[]] ([ArrayHelper]::EnsureArray($prefs.Repository.Favorites))
        $favorites = [System.Collections.Generic.List[string]]::new($currentFavs)
        
        # Already a favorite
        if ($favorites.Contains($repoPath)) {
            return $true
        }
        
        # Add and save
        $favorites.Add($repoPath)
        $prefs.Repository.Favorites = $favorites.ToArray()
        return $this.PreferencesService.SavePreferences($prefs)
    }
    
    # Remove a repository from favorites
    [bool] RemoveFavorite([string]$repoPath) {
        $prefs = $this.PreferencesService.LoadPreferences()
        $currentFavs = [string[]] ([ArrayHelper]::EnsureArray($prefs.Repository.Favorites))
        $favorites = [System.Collections.Generic.List[string]]::new($currentFavs)
        
        # Not a favorite check logic optimization
        if (-not $favorites.Contains($repoPath)) {
            return $true
        }
        
        # Remove and save
        $favorites.Remove($repoPath) | Out-Null
        $prefs.Repository.Favorites = $favorites.ToArray()
        return $this.PreferencesService.SavePreferences($prefs)
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
        $prefs = $this.PreferencesService.LoadPreferences()
        $prefs.Repository.Favorites = @()
        return $this.PreferencesService.SavePreferences($prefs)
    }
}
