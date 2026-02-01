<#
.SYNOPSIS
    ISearchService - Interface for repository search operations
    
.DESCRIPTION
    Abstraction for search/filter operations following DIP.
    Allows mocking in tests without actual filtering logic.
#>

class ISearchService {
    # Filters repositories by name or alias containing the search text
    [array] FilterRepositories([array]$allRepos, [string]$searchText) {
        throw "Not Implemented: FilterRepositories must be overridden"
    }
    
    # Search by exact repository name
    [RepositoryModel] FindByName([array]$allRepos, [string]$name) {
        throw "Not Implemented: FindByName must be overridden"
    }
    
    # Search by repository alias
    [RepositoryModel] FindByAlias([array]$allRepos, [string]$alias) {
        throw "Not Implemented: FindByAlias must be overridden"
    }
}
