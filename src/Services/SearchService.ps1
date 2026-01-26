<#
.SYNOPSIS
    SearchService - Fast in-memory repository search
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for filtering repositories
    - OCP: Can be extended with new search strategies
    - DIP: Works with RepositoryModel abstractions
    
    This service provides:
    - Fast case-insensitive filtering
    - Search by repository name OR alias
    - Optimized for real-time filtering as user types
#>

class SearchService {
    
    <#
    .SYNOPSIS
        Filters repositories by name or alias containing the search text
        
    .PARAMETER allRepos
        The complete list of repositories to filter
        
    .PARAMETER searchText
        The text to search for (case-insensitive)
        
    .RETURNS
        Array of matching repositories (preserves original order)
    #>
    [array] FilterRepositories([array]$allRepos, [string]$searchText) {
        if ($null -eq $allRepos -or $allRepos.Count -eq 0) {
            return @()
        }
        
        # Return all if search is empty
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            return $allRepos
        }
        
        $lowerSearch = $searchText.ToLower()
        
        # Filter by name or alias - O(n) linear scan, very fast for in-memory
        $filtered = [System.Collections.ArrayList]::new()
        
        foreach ($repo in $allRepos) {
            $matchesName = $repo.Name.ToLower().Contains($lowerSearch)
            $matchesAlias = $false
            
            if ($repo.HasAlias -and $null -ne $repo.AliasInfo -and -not [string]::IsNullOrEmpty($repo.AliasInfo.Alias)) {
                $matchesAlias = $repo.AliasInfo.Alias.ToLower().Contains($lowerSearch)
            }
            
            if ($matchesName -or $matchesAlias) {
                [void]$filtered.Add($repo)
            }
        }
        
        return $filtered.ToArray()
    }
    
    <#
    .SYNOPSIS
        Finds the index of a repository in a filtered list
        
    .PARAMETER filteredRepos
        The filtered list of repositories
        
    .PARAMETER targetRepo
        The repository to find
        
    .RETURNS
        Index of the repository, or 0 if not found
    #>
    [int] FindRepositoryIndex([array]$filteredRepos, [object]$targetRepo) {
        if ($null -eq $filteredRepos -or $filteredRepos.Count -eq 0 -or $null -eq $targetRepo) {
            return 0
        }
        
        for ($i = 0; $i -lt $filteredRepos.Count; $i++) {
            if ($filteredRepos[$i].FullPath -eq $targetRepo.FullPath) {
                return $i
            }
        }
        
        return 0
    }
    
    <#
    .SYNOPSIS
        Finds the original index of a filtered repository in the full list
        
    .PARAMETER allRepos
        The complete list of repositories
        
    .PARAMETER selectedRepo
        The selected repository from filtered results
        
    .RETURNS
        Original index in the full list, or -1 if not found
    #>
    [int] FindOriginalIndex([array]$allRepos, [object]$selectedRepo) {
        if ($null -eq $allRepos -or $allRepos.Count -eq 0 -or $null -eq $selectedRepo) {
            return -1
        }
        
        for ($i = 0; $i -lt $allRepos.Count; $i++) {
            if ($allRepos[$i].FullPath -eq $selectedRepo.FullPath) {
                return $i
            }
        }
        
        return -1
    }
}
