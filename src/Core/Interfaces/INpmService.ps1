<#
.SYNOPSIS
    INpmService - Interface for npm operations
    
.DESCRIPTION
    Abstraction for npm/node_modules operations following DIP.
    Allows mocking in tests without touching the filesystem.
#>

class INpmService {
    # Check if package.json exists in repository
    [bool] HasPackageJson([string]$repoPath) {
        throw "Not Implemented: HasPackageJson must be overridden"
    }
    
    # Check if node_modules exists in repository
    [bool] HasNodeModules([string]$repoPath) {
        throw "Not Implemented: HasNodeModules must be overridden"
    }
    
    # Check if package-lock.json exists
    [bool] HasPackageLock([string]$repoPath) {
        throw "Not Implemented: HasPackageLock must be overridden"
    }
    
    # Install npm dependencies
    [bool] InstallDependencies([string]$repoPath) {
        throw "Not Implemented: InstallDependencies must be overridden"
    }
    
    # Remove node_modules folder
    [bool] RemoveNodeModules([string]$repoPath, [bool]$removePackageLock = $false) {
        throw "Not Implemented: RemoveNodeModules must be overridden"
    }
    
    # Get node_modules size (in MB)
    [double] GetNodeModulesSize([string]$repoPath) {
        throw "Not Implemented: GetNodeModulesSize must be overridden"
    }
    
    # Read package.json content
    [PSCustomObject] GetPackageInfo([string]$repoPath) {
        throw "Not Implemented: GetPackageInfo must be overridden"
    }
    
    # Get npm executable path
    [string] GetNpmExecutablePath() {
        throw "Not Implemented: GetNpmExecutablePath must be overridden"
    }
}
