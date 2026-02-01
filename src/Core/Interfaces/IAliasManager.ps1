<#
.SYNOPSIS
    IAliasManager - Interface for alias and favorite management
    
.DESCRIPTION
    Abstraction for alias operations following DIP.
    Allows mocking in tests without touching configuration files.
#>

class IAliasManager {
    # Get all aliases as hashtable: RepoIdentifier -> AliasInfo
    [hashtable] GetAllAliases() {
        throw "Not Implemented: GetAllAliases must be overridden"
    }
    
    # Get alias for a specific repository (by path or name)
    [AliasInfo] GetAlias([string]$identifier) {
        throw "Not Implemented: GetAlias must be overridden"
    }
    
    # Set alias for a repository
    [bool] SetAlias([string]$repoPath, [string]$alias, [string]$color) {
        throw "Not Implemented: SetAlias must be overridden"
    }
    
    # Remove alias for a repository
    [bool] RemoveAlias([string]$identifier) {
        throw "Not Implemented: RemoveAlias must be overridden"
    }
    
    # Check if an alias exists
    [bool] HasAlias([string]$identifier) {
        throw "Not Implemented: HasAlias must be overridden"
    }
    
    # Check if alias name is already used
    [bool] IsAliasNameTaken([string]$alias) {
        throw "Not Implemented: IsAliasNameTaken must be overridden"
    }
}
