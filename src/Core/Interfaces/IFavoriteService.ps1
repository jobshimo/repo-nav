<#
.SYNOPSIS
    IFavoriteService - Interface for favorite management
    
.DESCRIPTION
    Abstraction for favorite operations following DIP.
    Allows mocking in tests without touching configuration files.
#>

class IFavoriteService {
    # Gets all favorite repository names
    [string[]] GetFavorites() {
        throw "Not Implemented: GetFavorites must be overridden"
    }
    
    # Check if a repository is marked as favorite
    [bool] IsFavorite([string]$repoPath) {
        throw "Not Implemented: IsFavorite must be overridden"
    }
    
    # Add a repository to favorites
    [bool] AddFavorite([string]$repoPath) {
        throw "Not Implemented: AddFavorite must be overridden"
    }
    
    # Remove a repository from favorites
    [bool] RemoveFavorite([string]$repoPath) {
        throw "Not Implemented: RemoveFavorite must be overridden"
    }
    
    # Toggle favorite status
    [bool] ToggleFavorite([string]$repoPath) {
        throw "Not Implemented: ToggleFavorite must be overridden"
    }
    
    # Get favorite count
    [int] GetFavoriteCount() {
        throw "Not Implemented: GetFavoriteCount must be overridden"
    }
    
    # Clear all favorites
    [bool] ClearAllFavorites() {
        throw "Not Implemented: ClearAllFavorites must be overridden"
    }
}
