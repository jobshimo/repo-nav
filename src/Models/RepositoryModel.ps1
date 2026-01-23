<#
.SYNOPSIS
    RepositoryModel - Rich domain model for a repository
    
.DESCRIPTION
    Following SRP (Single Responsibility Principle):
    This class represents a repository with all its metadata.
    It's a Rich Domain Model - contains data AND behavior related to that data.
    
    Follows OOP principles:
    - Encapsulation: All data is in one place
    - Single Responsibility: Only represents a repository
    - Composition: Uses GitStatusModel and AliasInfo
#>

class RepositoryModel {
    # Core properties
    [System.IO.DirectoryInfo] $DirectoryInfo
    [string] $Name
    [string] $FullPath
    
    # Alias properties
    [bool] $HasAlias
    [AliasInfo] $AliasInfo
    
    # Git properties (lazy-loaded, can be null)
    [GitStatusModel] $GitStatus
    
    # Additional metadata
    [bool] $HasNodeModules
    [bool] $IsFavorite
    
    # Constructor
    RepositoryModel([System.IO.DirectoryInfo]$directoryInfo) {
        $this.DirectoryInfo = $directoryInfo
        $this.Name = $directoryInfo.Name
        $this.FullPath = $directoryInfo.FullName
        
        # Initialize flags
        $this.HasAlias = $false
        $this.AliasInfo = $null
        $this.GitStatus = $null
        $this.HasNodeModules = $false
        $this.IsFavorite = $false
    }
    
    # Set alias information
    [void] SetAlias([AliasInfo]$aliasInfo) {
        if ($aliasInfo -and $aliasInfo.IsValid()) {
            $this.AliasInfo = $aliasInfo
            $this.HasAlias = $true
        }
    }
    
    # Remove alias
    [void] RemoveAlias() {
        $this.AliasInfo = $null
        $this.HasAlias = $false
    }
    
    # Set git status
    [void] SetGitStatus([GitStatusModel]$gitStatus) {
        $this.GitStatus = $gitStatus
    }
    
    # Check if git status is loaded
    [bool] HasGitStatusLoaded() {
        return $this.GitStatus -ne $null
    }
    
    # Check if node_modules exists
    [void] CheckNodeModules() {
        $nodeModulesPath = Join-Path $this.FullPath "node_modules"
        $this.HasNodeModules = Test-Path $nodeModulesPath
    }
    
    # Check if package.json exists
    [bool] HasPackageJson() {
        $packageJsonPath = Join-Path $this.FullPath "package.json"
        return Test-Path $packageJsonPath
    }
    
    # Mark as favorite
    [void] MarkAsFavorite([bool]$isFavorite) {
        $this.IsFavorite = $isFavorite
    }
    
    # ToString for debugging
    [string] ToString() {
        $status = $this.Name
        if ($this.HasAlias) {
            $status += " (Alias: $($this.AliasInfo.Alias))"
        }
        if ($this.IsFavorite) {
            $status += " [FAV]"
        }
        if ($this.GitStatus) {
            $status += " | Git: $($this.GitStatus.ToString())"
        }
        return $status
    }
}
