<#
.SYNOPSIS
    GitReadService - Handles read-only Git operations (ISP)
#>
class GitReadService : IGitReadService {
    
    # Check if a directory is a Git repository
    [bool] IsGitRepository([string]$repoPath) {
        $gitPath = Join-Path $repoPath ".git"
        return Test-Path $gitPath
    }
    
    # Get current branch name
    [string] GetCurrentBranch([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) { return "" }
        
        Push-Location $repoPath
        try {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0) { return $branch }
            return ""
        }
        finally { Pop-Location }
    }
    
    # Check if repository has uncommitted changes
    [bool] HasUncommittedChanges([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) { return $false }
        
        Push-Location $repoPath
        try {
            $status = git status --porcelain 2>$null
            if ($LASTEXITCODE -eq 0) {
                return -not [string]::IsNullOrWhiteSpace($status)
            }
            return $false
        }
        finally { Pop-Location }
    }
    
    # Check if repository has unpushed commits
    [bool] HasUnpushedCommits([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) { return $false }
        
        Push-Location $repoPath
        try {
            $branch = $this.GetCurrentBranch($repoPath)
            if ([string]::IsNullOrWhiteSpace($branch)) { return $false }
            
            $unpushed = git log origin/$branch..HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                return -not [string]::IsNullOrWhiteSpace($unpushed)
            }
            return $false
        }
        catch { return $false }
        finally { Pop-Location }
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
    
    # Validate Git URL
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
    
    # Get remote URL
    [string] GetRemoteUrl([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) { return "" }
        
        Push-Location $repoPath
        try {
            $remoteUrl = git config --get remote.origin.url 2>$null
            if ($LASTEXITCODE -eq 0) { return $remoteUrl }
            return ""
        }
        finally { Pop-Location }
    }
    
    # Get HTTPS URL for repository (for browser)
    [string] GetRepoUrl([string]$repoPath) {
        $remote = $this.GetRemoteUrl($repoPath)
        if ([string]::IsNullOrWhiteSpace($remote)) { return "" }
        
        if ($remote -match '^git@github\.com:(.+)\.git$') {
            return "https://github.com/$($matches[1])"
        }
        if ($remote -match '^(https://.+)\.git$') {
            return $matches[1]
        }
        return $remote
    }
    
    # Count contained repositories
    [int] CountContainedRepositories([string]$path) {
        $count = 0
        $subdirs = Get-ChildItem -Directory -Path $path -ErrorAction SilentlyContinue
        foreach ($subdir in $subdirs) {
            if ($this.IsGitRepository($subdir.FullName)) { $count++ }
        }
        return $count
    }
    
    # Check if container directory
    [bool] IsContainerDirectory([string]$path) {
        if ($this.IsGitRepository($path)) { return $false }
        return $true
    }

    # Get local branches
    [string[]] GetBranches([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) { return @() }
        
        Push-Location $repoPath
        try {
            $branches = git branch --format="%(refname:short)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $branches) { return $branches }
            return @()
        }
        finally { Pop-Location }
    }

    # Get remote branches
    [string[]] GetRemoteBranches([string]$repoPath) {
        if (-not $this.IsGitRepository($repoPath)) { return @() }
        
        Push-Location $repoPath
        try {
            $branches = git branch -r --format="%(refname:short)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $branches) {
                return @($branches) | Where-Object { $_ -notmatch "HEAD ->" }
            }
            return @()
        }
        finally { Pop-Location }
    }
    # Get branch tracking status (ahead/behind)
    [hashtable] GetBranchTrackingStatus([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) { return @{ Ahead = 0; Behind = 0 } }
        
        Push-Location $repoPath
        try {
            $upstream = git rev-parse --verify "${branchName}@{upstream}" 2>$null
            if ($LASTEXITCODE -ne 0) {
                return @{ Ahead = 0; Behind = 0 }
            }

            $counts = git rev-list --left-right --count "${branchName}...${branchName}@{upstream}" 2>$null
            
            if ($LASTEXITCODE -eq 0 -and $counts -match '(\d+)\s+(\d+)') {
                return @{ Ahead = [int]$matches[1]; Behind = [int]$matches[2] }
            }
            return @{ Ahead = 0; Behind = 0 }
        }
        catch { return @{ Ahead = 0; Behind = 0 } }
        finally { Pop-Location }
    }

    # Check if remote branch exists
    [bool] RemoteBranchExists([string]$repoPath, [string]$branchName) {
        if (-not $this.IsGitRepository($repoPath)) { return $false }
        
        Push-Location $repoPath
        try {
            $remoteRef = git rev-parse --verify "origin/${branchName}" 2>$null
            return ($LASTEXITCODE -eq 0)
        }
        finally { Pop-Location }
    }
}

