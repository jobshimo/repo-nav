<#
.SYNOPSIS
    RepositorySorter - Handles sorting logic for repository collections
    
.DESCRIPTION
    Following SRP: This class has the single responsibility of sorting repositories.
    Extracted from RepositoryManager to reduce its complexity.
    
    Supports:
    - Alphabetical sorting by name
    - Favorites-first sorting (favorites on top, then alphabetical)
#>

class RepositorySorter {
    # Sort repositories based on user preferences
    # Parameters:
    #   $repositories - ArrayList of RepositoryModel objects
    #   $favoritesOnTop - Whether to place favorites first
    # Returns: Sorted array of RepositoryModel
    [array] Sort([System.Collections.ArrayList]$repositories, [bool]$favoritesOnTop) {
        if ($favoritesOnTop) {
            # Favorites first (descending by IsFavorite), then alphabetically by Name
            return @($repositories | Sort-Object @{Expression = {-$_.IsFavorite}}, Name)
        } else {
            # Just alphabetically by Name
            return @($repositories | Sort-Object Name)
        }
    }
}
