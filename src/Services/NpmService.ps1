<#
.SYNOPSIS
    NpmService - Manages npm operations for repositories
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for npm/node_modules operations
    - DIP: Provides abstraction for npm operations
    - OCP: Can be extended with new npm operations
    
    This service handles:
    - Checking if package.json exists
    - Checking if node_modules exists
    - Installing dependencies
    - Removing node_modules
    - Package.json validation
#>

class NpmService {
    
    # Check if package.json exists in repository
    [bool] HasPackageJson([string]$repoPath) {
        $packageJsonPath = Join-Path $repoPath "package.json"
        return Test-Path $packageJsonPath
    }
    
    # Check if node_modules exists in repository
    [bool] HasNodeModules([string]$repoPath) {
        $nodeModulesPath = Join-Path $repoPath "node_modules"
        return Test-Path $nodeModulesPath
    }
    
    # Check if package-lock.json exists
    [bool] HasPackageLock([string]$repoPath) {
        $packageLockPath = Join-Path $repoPath "package-lock.json"
        return Test-Path $packageLockPath
    }
    
    # Install npm dependencies
    # Delegates to helper function outside class to avoid PowerShell output issues
    [bool] InstallDependencies([string]$repoPath) {
        # Note: This is not used directly anymore, but kept for compatibility
        # The NavigatorController calls Invoke-NpmInstall directly
        if (-not $this.HasPackageJson($repoPath)) {
            Write-Warning "No package.json found in $repoPath"
            return $false
        }
        
        return $true
    }
    
    # Remove node_modules folder
    [bool] RemoveNodeModules([string]$repoPath, [bool]$removePackageLock = $false) {
        $nodeModulesPath = Join-Path $repoPath "node_modules"
        
        if (-not (Test-Path $nodeModulesPath)) {
            Write-Warning "No node_modules folder found in $repoPath"
            return $false
        }
        
        try {
            Write-Host "Removing node_modules from $repoPath..." -ForegroundColor ([Constants]::ColorWarning)
            Remove-Item -Path $nodeModulesPath -Recurse -Force -ErrorAction Stop
            Write-Host "node_modules removed successfully!" -ForegroundColor ([Constants]::ColorSuccess)
            
            # Remove package-lock.json if requested
            if ($removePackageLock) {
                $packageLockPath = Join-Path $repoPath "package-lock.json"
                if (Test-Path $packageLockPath) {
                    Remove-Item -Path $packageLockPath -Force -ErrorAction Stop
                    Write-Host "package-lock.json removed successfully!" -ForegroundColor ([Constants]::ColorSuccess)
                }
            }
            
            return $true
        }
        catch {
            Write-Error "Error removing node_modules: $_"
            return $false
        }
    }
    
    # Get node_modules size (in MB)
    [double] GetNodeModulesSize([string]$repoPath) {
        $nodeModulesPath = Join-Path $repoPath "node_modules"
        
        if (-not (Test-Path $nodeModulesPath)) {
            return 0
        }
        
        try {
            $size = (Get-ChildItem -Path $nodeModulesPath -Recurse -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            return [Math]::Round($size / 1MB, 2)
        }
        catch {
            return 0
        }
    }
    
    # Read package.json content
    [PSCustomObject] GetPackageInfo([string]$repoPath) {
        if (-not $this.HasPackageJson($repoPath)) {
            return $null
        }
        
        try {
            $packageJsonPath = Join-Path $repoPath "package.json"
            $content = Get-Content $packageJsonPath -Raw
            return ConvertFrom-Json $content
        }
        catch {
            Write-Warning "Error reading package.json: $_"
            return $null
        }
    }
    
    # Get package name from package.json
    [string] GetPackageName([string]$repoPath) {
        $packageInfo = $this.GetPackageInfo($repoPath)
        if ($packageInfo -and $packageInfo.name) {
            return $packageInfo.name
        }
        return ""
    }
    
    # Check if repository is an npm project
    [bool] IsNpmProject([string]$repoPath) {
        return $this.HasPackageJson($repoPath)
    }
    
    # Update RepositoryModel with npm information
    [void] UpdateRepositoryModel([RepositoryModel]$repository) {
        $repository.CheckNodeModules()
    }
}
