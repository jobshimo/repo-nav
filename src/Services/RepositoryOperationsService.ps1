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
    <#
    .SYNOPSIS
        Clones a repository from a Git URL
    #>
    [OperationResult] CloneRepository([string]$url, [string]$customName, [string]$basePath) {
        # Validate URL
        if (-not $this.GitService.IsValidGitUrl($url)) {
            return [OperationResult]::Fail("Invalid Git URL format")
        }
        
        # Determine folder name
        $repoName = if (-not [string]::IsNullOrWhiteSpace($customName)) { 
            $customName 
        }
        else { 
            $this.GitService.GetRepoNameFromUrl($url) 
        }
        
        if ([string]::IsNullOrWhiteSpace($repoName)) {
            return [OperationResult]::Fail("Could not determine repository name from URL")
        }
        
        # Check if target already exists
        $targetPath = Join-Path $basePath $repoName
        if (Test-Path $targetPath) {
            return [OperationResult]::Fail("Folder '$repoName' already exists")
        }
        
        # Perform clone
        try {
            $result = $this.GitService.CloneRepository($url, $basePath, $repoName)
            
            if ($result.Success) {
                # We can attach extra data if needed, like RepoName and TargetPath
                # For now using Data to pass a hashtable with details is acceptable or just relying on success
                return [OperationResult]::Ok(@{ RepoName = $repoName; TargetPath = $targetPath }, "Repository '$repoName' cloned successfully")
            }
            else {
                return [OperationResult]::Fail("Git clone command failed: $($result.Message)")
            }
        }
        catch {
            return [OperationResult]::Fail("Error during clone: $_")
        }
    }
    
    <#
    .SYNOPSIS
        Deletes a repository from disk
    #>
    [OperationResult] DeleteRepository([RepositoryModel]$repository, [bool]$force = $false) {
        # Validate path exists
        if (-not (Test-Path $repository.FullPath)) {
             return [OperationResult]::Fail("Repository path does not exist")
        }
        
        # Safety check for uncommitted changes (if not forced)
        if (-not $force -and $repository.GitStatus -and $repository.GitStatus.NeedsAttention()) {
             # Special Fail with data indicating force is required?
             # For now standard message.
             return [OperationResult]::Fail("Repository has uncommitted changes or unpushed commits. Use force to delete anyway.", @{ RequiresForce = $true })
        }
        
        # Perform deletion
        try {
            Remove-Item -Path $repository.FullPath -Recurse -Force -ErrorAction Stop
            
            return [OperationResult]::Ok(@{ DeletedPath = $repository.FullPath }, "Repository '$($repository.Name)' deleted successfully")
        }
        catch {
             return [OperationResult]::Fail("Error deleting repository: $_")
        }
    }
    
    <#
    .SYNOPSIS
        Creates a new folder
    #>
    [OperationResult] CreateFolder([string]$name, [string]$parentPath) {
        # Validate name (no spaces)
        if ($name -match '\s') {
            return [OperationResult]::Fail("Folder name cannot contain spaces.")
        }
        
        # Validate parent path
        if (-not (Test-Path $parentPath)) {
            return [OperationResult]::Fail("Parent path does not exist.")
        }
        
        $newPath = Join-Path $parentPath $name
        
        if (Test-Path $newPath) {
             return [OperationResult]::Fail("Folder '$name' already exists.")
        }
        
        try {
            New-Item -Path $newPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            return [OperationResult]::Ok($null, "Folder created successfully.")
        }
        catch {
             return [OperationResult]::Fail("Error creating folder: $_")
        }
    }

    <#
    .SYNOPSIS
        Validates if a repository can be safely deleted
    #>
    [hashtable] ValidateDeleteSafety([RepositoryModel]$repository) {
        # Keeping this as hashtable as it returns a complex validation structure used by UI specifically
        # Or should we convert to OperationResult? 
        # ValidateDeleteSafety is more of a "Query" than an "Operation". 
        # Let's keep it as is or change to specific class. For now as is to avoid breaking too much UI.
        
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
    #>
    [hashtable] GetCloneInfo([string]$url, [string]$basePath) {
        # Query method, keeping hashtable for now or specific DTO.
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
    #>
    [OperationResult] DeleteFolder([RepositoryModel]$folder) {
        # Check if path exists
        if (-not (Test-Path $folder.FullPath)) {
             return [OperationResult]::Fail("Path does not exist")
        }
        
        # Delete empty folder
        try {
            Remove-Item -Path $folder.FullPath -Force -ErrorAction Stop
            
            return [OperationResult]::Ok(@{ DeletedPath = $folder.FullPath }, "Folder deleted successfully")
        }
        catch {
             return [OperationResult]::Fail("Error deleting folder: $_")
        }
    }
    
    <#
    .SYNOPSIS
        Checks if a folder is empty (no files, no subfolders)
    #>
    [bool] IsFolderEmpty([string]$folderPath) {
        if (-not (Test-Path $folderPath)) {
            return $false
        }
        
        $hasItems = Get-ChildItem -Path $folderPath -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        return ($null -eq $hasItems)
    }
}
