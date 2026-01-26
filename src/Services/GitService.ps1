<#
.SYNOPSIS
    GitService - Manages Git operations for repositories
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for Git operations
    - DIP: Provides abstraction for Git operations (others depend on this)
    - OCP: Can be extended with new Git operations
    
    This service handles:
    - Git status checking
    - Branch information
    - Uncommitted changes detection
    - Unpushed commits detection
    - Git validation
#>

class GitService {
    
    # Check if a directory is a Git repository
    [bool] IsGitRepository([string]$repoPath) {
        $gitPath = Join-Path $repoPath ".git"
        return Test-Path $gitPath
    }
    
    # Get current branch name
    [string] GetCurrentBranch([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return ""
        }
        
        Push-Location $repoPath
        try {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $branch
            }
            return ""
        }
        finally {
            Pop-Location
        }
    }
    
    # Check if repository has uncommitted changes
    [bool] HasUncommittedChanges([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return $false
        }
        
        Push-Location $repoPath
        try {
            $status = git status --porcelain 2>$null
            if ($LASTEXITCODE -eq 0) {
                return -not [string]::IsNullOrWhiteSpace($status)
            }
            return $false
        }
        finally {
            Pop-Location
        }
    }
    
    # Check if repository has unpushed commits
    [bool] HasUnpushedCommits([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return $false
        }
        
        Push-Location $repoPath
        try {
            # Get current branch
            $branch = $this.GetCurrentBranch($repoPath)
            if ([string]::IsNullOrWhiteSpace($branch)) {
                return $false
            }
            
            # Check if there are unpushed commits
            $unpushed = git log origin/$branch..HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                return -not [string]::IsNullOrWhiteSpace($unpushed)
            }
            return $false
        }
        catch {
            return $false
        }
        finally {
            Pop-Location
        }
    }
    
    # Get complete Git status for a repository
    [GitStatusModel] GetGitStatus([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return [GitStatusModel]::new()
        }
        
        $branch = $this.GetCurrentBranch($repoPath)
        $hasUncommitted = $this.HasUncommittedChanges($repoPath)
        $hasUnpushed = $this.HasUnpushedCommits($repoPath)
        
        return [GitStatusModel]::new($true, $hasUncommitted, $hasUnpushed, $branch)
    }
    
    # Get Git status for a RepositoryModel
    [GitStatusModel] GetGitStatus([RepositoryModel]$repository) {
        return $this.GetGitStatus($repository.FullPath)
    }
    
    # Validate if a URL is a valid Git HTTPS URL
    [bool] IsValidGitUrl([string]$url) {
        return $url -match '^https://github\.com/[\w\-]+/[\w\-\.]+\.git$' -or 
               $url -match '^https://github\.com/[\w\-]+/[\w\-\.]+$'
    }
    
    # Extract repository name from Git URL
    [string] GetRepoNameFromUrl([string]$url) {
        if ($url -match '/([^/]+)\.git$' -or $url -match '/([^/]+)$') {
            return $matches[1]
        }
        return ""
    }
    
    # Clone a repository
    [object] CloneRepository([string]$url, [string]$targetPath, [string]$folderName = "") {
        if (-not $this.IsValidGitUrl($url)) {
            return @{ Success = $false; Output = "Invalid Git URL format" }
        }
        
        # Ensure URL ends with .git
        if ($url -notmatch '\.git$') {
            $url = "$url.git"
        }
        
        Push-Location $targetPath
        try {
            if ([string]::IsNullOrWhiteSpace($folderName)) {
                $output = git clone $url 2>&1
            }
            else {
                $output = git clone $url $folderName 2>&1
            }
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            return @{ Success = $success; Output = $outStr }
        }
        catch {
            return @{ Success = $false; Output = $_.ToString() }
        }
        finally {
            Pop-Location
        }
    }
    
    # Get remote URL for a repository
    [string] GetRemoteUrl([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return ""
        }
        
        Push-Location $repoPath
        try {
            $remoteUrl = git config --get remote.origin.url 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $remoteUrl
            }
            return ""
        }
        finally {
            Pop-Location
        }
    }
    
    # Check if a directory contains Git repositories in its subdirectories
    # Returns the count of repositories found (0 if none)
    [int] CountContainedRepositories([string]$path) {
        $count = 0
        $subdirs = Get-ChildItem -Directory -Path $path -ErrorAction SilentlyContinue
        
        foreach ($subdir in $subdirs) {
            if ($this.IsGitRepository($subdir.FullName)) {
                $count++
            }
        }
        
        return $count
    }
    
    # Check if a directory is a container (has repos inside but is not a repo itself)
    [bool] IsContainerDirectory([string]$path) {
        # If it's already a git repo, it's not a container
        if ($this.IsGitRepository($path)) {
            return $false
        }
        
        # Check if any subdirectory is a git repo OR if the directory is empty/has no git repos but is structured to be one
        # Current logic: If it's not a git repo, treat as container so user can enter and create repos or folders there.
        # This allows navigating empty folder structures.
        return $true
    }

    # Get local branches
    [string[]] GetBranches([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @()
        }
        
        Push-Location $repoPath
        try {
            # --format=%(refname:short) gives just the branch name
            $branches = git branch --format="%(refname:short)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $branches) {
                return $branches
            }
            return @()
        }
        finally {
            Pop-Location
        }
    }

    # Create a new branch from a source branch
    [object] CreateBranch([string]$repoPath, [string]$newBranchName, [string]$sourceBranch) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            # git checkout -b new_branch source_branch
            $output = git checkout -b $newBranchName $sourceBranch 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            return @{ Success = $success; Output = $outStr }
        }
        catch {
             return @{ Success = $false; Output = $_.ToString() }
        }
        finally {
            Pop-Location
        }
    }

    # Checkout a branch
    [object] Checkout([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git checkout $branchName 2>&1
            $success = ($LASTEXITCODE -eq 0)
            
            # If success, output might be "Switched to branch..." which isn't an error.
            # Convert array to string if needed
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            return @{ Success = $success; Output = $outStr }
        }
        catch {
             return @{ Success = $false; Output = $_.ToString() }
        }
        finally {
            Pop-Location
        }
    }

    # Merge a branch into the current branch
    [object] Merge([string]$repoPath, [string]$branchToMerge) {
        if (-not $this.IsGitRepository($repoPath)) {
            return @{ Success = $false; Output = "Not a git repository" }
        }
        
        Push-Location $repoPath
        try {
            $output = git merge $branchToMerge 2>&1
            $success = ($LASTEXITCODE -eq 0)
            $outStr = if ($output) { $output -join "`n" } else { "" }
            
            return @{ Success = $success; Output = $outStr }
        }
        catch {
             return @{ Success = $false; Output = $_.ToString() }
        }
        finally {
            Pop-Location
        }
    }
}
