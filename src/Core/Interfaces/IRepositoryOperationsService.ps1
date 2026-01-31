<#
.SYNOPSIS
    IRepositoryOperationsService - Interface for repository lifecycle operations
    
.DESCRIPTION
    Abstraction for repository clone/delete operations following DIP.
    Allows mocking in tests without actual filesystem operations.
#>

class IRepositoryOperationsService {
    # Clones a repository from a Git URL
    [OperationResult] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        throw "Not Implemented: CloneRepository must be overridden"
    }
    
    # Deletes a repository folder
    [OperationResult] DeleteRepository([string]$repoPath) {
        throw "Not Implemented: DeleteRepository must be overridden"
    }
    
    # Opens a repository in file explorer
    [void] OpenInExplorer([string]$repoPath) {
        throw "Not Implemented: OpenInExplorer must be overridden"
    }
    
    # Opens a repository in VS Code
    [void] OpenInVSCode([string]$repoPath) {
        throw "Not Implemented: OpenInVSCode must be overridden"
    }
}
