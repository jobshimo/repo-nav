<#
.SYNOPSIS
    RepositoryOperationsService - Handles repository lifecycle operations
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for repository clone/delete operations
    - DIP: Depends on GitService abstraction
    - OCP: Can be extended for new operations (archive, fork, etc.)
    
    Extracted from RepositoryManager to separate lifecycle operations from coordination.
#>

class RepositoryOperationsService {
    # Dependencies
    [GitService] $GitService
    
    # Constructor with dependency injection
    RepositoryOperationsService([GitService]$gitService) {
        $this.GitService = $gitService
    }
    
    <#
    .SYNOPSIS
        Clones a repository from a Git URL
        
    .PARAMETER url
        The Git URL to clone from
        
    .PARAMETER customName
        Optional custom folder name (uses repo name from URL if empty)
        
    .PARAMETER basePath
        The base path where the repository will be cloned
        
    .RETURNS
        Hashtable with Success (bool) and Message (string)
    #>
    [hashtable] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        # Validate URL
        if (-not $this.GitService.IsValidGitUrl($url)) {
            return @{ 
                Success = $false
                Message = "Invalid Git URL format"
            }
        }
        
        # Determine folder name
        $repoName = if (-not [string]::IsNullOrWhiteSpace($customName)) { 
            $customName 
        }
        else { 
            $this.GitService.GetRepoNameFromUrl($url) 
        }
        
        if ([string]::IsNullOrWhiteSpace($repoName)) {
            return @{ 
                Success = $false
                Message = "Could not determine repository name from URL"
            }
        }
        
        # Check if target already exists
        $targetPath = Join-Path $basePath $repoName
        if (Test-Path $targetPath) {
            return @{ 
                Success = $false
                Message = "Folder '$repoName' already exists"
            }
        }
        
        # Perform clone
        try {
            $success = $this.GitService.CloneRepository($url, $basePath, $repoName)
            
            if ($success) {
                return @{ 
                    Success = $true
                    Message = "Repository '$repoName' cloned successfully"
                    RepoName = $repoName
                    TargetPath = $targetPath
                }
            }
            else {
                return @{ 
                    Success = $false
                    Message = "Git clone command failed"
                }
            }
        }
        catch {
            return @{ 
                Success = $false
                Message = "Error during clone: $_"
            }
        }
    }
    
    <#
    .SYNOPSIS
        Deletes a repository from disk
        
    .PARAMETER repository
        The RepositoryModel to delete
        
    .PARAMETER force
        If true, deletes even with uncommitted changes
        
    .RETURNS
        Hashtable with Success (bool) and Message (string)
    #>
    [hashtable] DeleteRepository([RepositoryModel]$repository, [bool]$force = $false) {
        # Validate path exists
        if (-not (Test-Path $repository.FullPath)) {
            return @{ 
                Success = $false
                Message = "Repository path does not exist"
            }
        }
        
        # Safety check for uncommitted changes (if not forced)
        if (-not $force -and $repository.GitStatus -and $repository.GitStatus.NeedsAttention()) {
            return @{ 
                Success = $false
                Message = "Repository has uncommitted changes or unpushed commits. Use force to delete anyway."
                RequiresForce = $true
            }
        }
        
        # Perform deletion
        try {
            Remove-Item -Path $repository.FullPath -Recurse -Force -ErrorAction Stop
            
            return @{ 
                Success = $true
                Message = "Repository '$($repository.Name)' deleted successfully"
                DeletedPath = $repository.FullPath
            }
        }
        catch {
            return @{ 
                Success = $false
                Message = "Error deleting repository: $_"
            }
        }
    }
    
    <#
    .SYNOPSIS
        Creates a new folder
    #>
    [hashtable] CreateFolder([string]$name, [string]$parentPath) {
        # Validate name (no spaces)
        if ($name -match '\s') {
            return @{
                Success = $false
                Message = "Folder name cannot contain spaces."
            }
        }
        
        # Validate parent path
        if (-not (Test-Path $parentPath)) {
            return @{
                Success = $false
                Message = "Parent path does not exist."
            }
        }
        
        $newPath = Join-Path $parentPath $name
        
        if (Test-Path $newPath) {
             return @{
                Success = $false
                Message = "Folder '$name' already exists."
            }
        }
        
        try {
            New-Item -Path $newPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            return @{
                Success = $true
                Message = "Folder created successfully."
            }
        }
        catch {
             return @{
                Success = $false
                Message = "Error creating folder: $_"
            }
        }
    }

    <#
    .SYNOPSIS
        Validates if a repository can be safely deleted
        
    .PARAMETER repository
        The RepositoryModel to validate
        
    .RETURNS
        Hashtable with CanDelete (bool), Warnings (array), and RequiresForce (bool)
    #>
    [hashtable] ValidateDeleteSafety([RepositoryModel]$repository) {
        $warnings = [System.Collections.ArrayList]::new()
        $requiresForce = $false
        
        # Check if path exists
        if (-not (Test-Path $repository.FullPath)) {
            return @{
                CanDelete     = $false
                Warnings      = @("Repository path does not exist")
                RequiresForce = $false
            }
        }
        
        # Check for Git status issues
        if ($repository.GitStatus) {
            if ($repository.GitStatus.HasUncommittedChanges) {
                $warnings.Add("Has uncommitted changes") | Out-Null
                $requiresForce = $true
            }
            if ($repository.GitStatus.HasUnpushedCommits) {
                $warnings.Add("Has unpushed commits") | Out-Null
                $requiresForce = $true
            }
        }
        
        # Check for node_modules (large folder warning)
        if ($repository.HasNodeModules) {
            $warnings.Add("Contains node_modules folder (may take time to delete)") | Out-Null
        }
        
        return @{
            CanDelete     = $true
            Warnings      = $warnings.ToArray()
            RequiresForce = $requiresForce
        }
    }
    
    <#
    .SYNOPSIS
        Gets information about a potential clone target
        
    .PARAMETER url
        The Git URL to analyze
        
    .PARAMETER basePath
        The base path where the repository would be cloned
        
    .RETURNS
        Hashtable with repo info and validation status
    #>
    [hashtable] GetCloneInfo([string]$url, [string]$basePath) {
        $isValid = $this.GitService.IsValidGitUrl($url)
        $repoName = $this.GitService.GetRepoNameFromUrl($url)
        $targetPath = if ($repoName) { Join-Path $basePath $repoName } else { "" }
        $targetExists = if ($targetPath) { Test-Path $targetPath } else { $false }
        
        return @{
            IsValidUrl   = $isValid
            RepoName     = $repoName
            TargetPath   = $targetPath
            TargetExists = $targetExists
            CanClone     = $isValid -and -not $targetExists
        }
    }
    
    <#
    .SYNOPSIS
        Deletes a folder if it is empty
        
    .PARAMETER folder
        The folder (RepositoryModel) to delete
        
    .RETURNS
        Hashtable with Success (bool) and Message (string)
    #>
    [hashtable] DeleteFolder([RepositoryModel]$folder) {
        # Check if path exists
        if (-not (Test-Path $folder.FullPath)) {
             return @{
                Success = $false
                Message = "Path does not exist"
            }
        }

        # Check if folder is empty
        # We look for any item. If we find one, it's not empty.
        $hasItems = Get-ChildItem -Path $folder.FullPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($hasItems) {
            return @{
                Success = $false
                Message = "Cannot delete: Folder is not empty"
                IsNotEmpty = $true
            }
        }
        
        # Delete empty folder
        try {
            Remove-Item -Path $folder.FullPath -Force -Recurse -ErrorAction Stop
            
            return @{
                Success = $true
                Message = "Folder deleted successfully"
                DeletedPath = $folder.FullPath
            }
        }
        catch {
            return @{
                Success = $false
                Message = "Error deleting folder: $_"
            }
        }
    }
}
