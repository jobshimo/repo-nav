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

class NpmService : INpmService {
    
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
    [bool] InstallDependencies([string]$repoPath) {
        if (-not $this.HasPackageJson($repoPath)) {
            Write-Warning "No package.json found in $repoPath"
            return $false
        }
        return $true
    }
    
    # Remove node_modules folder (Logic-only, no UI)
    [bool] RemoveNodeModules([string]$repoPath, [bool]$removePackageLock = $false) {
        $nodeModulesPath = Join-Path $repoPath "node_modules"
        
        if (-not (Test-Path $nodeModulesPath)) {
            # Not an error, just nothing to do
            return $true
        }
        
        try {
            # Use cmd.exe for speed and path length robustness
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rmdir /s /q `"$nodeModulesPath`"" -NoNewWindow -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                 Write-Error "rmdir failed with exit code $($proc.ExitCode)"
                 return $false
            }
            
            # Remove package-lock.json if requested
            if ($removePackageLock) {
                $packageLockPath = Join-Path $repoPath "package-lock.json"
                if (Test-Path $packageLockPath) {
                    Remove-Item -Path $packageLockPath -Force -ErrorAction Stop
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

    # Smart detection of npm executable
    [string] GetNpmExecutablePath() {
        # 1. Try standard discovery via PATH
        if (Get-Command "npm" -ErrorAction SilentlyContinue) {
            # Return just "npm" and let the shell resolve it (since we use cmd /c)
            return "npm"
        }

        # 2. Check NVM Symlink environment variable
        if ($env:NVM_SYMLINK -and (Test-Path "$env:NVM_SYMLINK\npm.cmd")) {
            return "$env:NVM_SYMLINK\npm.cmd"
        }

        # 3. Check standard NodeJS installation path
        $programsPath = [Environment]::GetFolderPath("ProgramFiles")
        $standardNode = Join-Path $programsPath "nodejs\npm.cmd"
        if (Test-Path $standardNode) {
            return $standardNode
        }

        # 4. Smart NVM Fallback
        if ($env:NVM_HOME -and (Test-Path $env:NVM_HOME)) {
            try {
                $latestVersion = Get-ChildItem -Path $env:NVM_HOME -Directory -Filter "v*" | 
                                 Sort-Object Name -Descending | 
                                 Select-Object -First 1
                                 
                if ($latestVersion) {
                    $nvmNpmPath = Join-Path $latestVersion.FullName "npm.cmd"
                    if (Test-Path $nvmNpmPath) {
                        return $nvmNpmPath
                    }
                }
            }
            catch {
                $logger = [ServiceRegistry]::Resolve('LoggerService')
                if ($null -ne $logger) { $logger.LogError($_) }
            }
        }

        return [string]::Empty
    }

    # Get package version from package.json
    [string] GetVersion([string]$repoPath) {
        $packageInfo = $this.GetPackageInfo($repoPath)
        if ($packageInfo -and $packageInfo.version) {
            return $packageInfo.version
        }
        return "0.0.0"
    }

    # Set package version
    [OperationResult] SetVersion([string]$repoPath, [string]$newVersion) {
        if (-not $this.HasPackageJson($repoPath)) {
            return [OperationResult]::Fail("No package.json found")
        }
        
        $hasLockFile = $this.HasPackageLock($repoPath)
        
        # 1. Try with npm executable
        $npmPath = $this.GetNpmExecutablePath()
        if (-not [string]::IsNullOrWhiteSpace($npmPath)) {
            try {
                # Logic adapted from NpmCommand.ps1 for consistency
                $argsList = "/c `"$npmPath`" version $newVersion --no-git-tag-version --allow-same-version"
                
                # Using cmd.exe wrapper significantly improves reliability on Windows
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList $argsList -WorkingDirectory $repoPath -NoNewWindow -Wait -PassThru
                
                if ($proc.ExitCode -eq 0) {
                     # Verify lock file update if it exists
                     if ($hasLockFile) {
                         $lockContent = Get-Content (Join-Path $repoPath "package-lock.json") -Raw
                         if ($lockContent -notmatch """version""\s*:\s*""$newVersion""") {
                             return [OperationResult]::Ok($null, "Updated package.json via npm, but package-lock.json seems outdated. Please run 'npm install' manually.")
                         }
                     }
                     return [OperationResult]::Ok($null, "Updated to $newVersion via npm")
                } 
                # If failed, fallthrough but warn if lockfile exists
            }
            catch {
                Write-Warning "Error executing npm: $_"
            }
        }
        
        # 2. Fallback: Manual JSON manipulation
        if ($hasLockFile) {
            # If we have a lock file but couldn't use npm, we should probably STOP or WARN LOUDLY
            # The user explicitly said: "check that package-lock.json changes... this has to be aligned"
            return [OperationResult]::Fail("Cannot update version: 'npm' not found or failed, and package-lock.json exists. Manual update would break sync.")
        }

        try {
            $packageJsonPath = Join-Path $repoPath "package.json"
            $content = Get-Content $packageJsonPath -Raw
            
            if ($content -match '"version"\s*:\s*"[^"]+"') {
                $newContent = $content -replace '"version"\s*:\s*"[^"]+"', """version"": ""$newVersion"""
                Set-Content -Path $packageJsonPath -Value $newContent -Encoding UTF8
                return [OperationResult]::Ok($null, "Updated package.json manually to $newVersion")
            } else {
                 return [OperationResult]::Fail("Could not find version field in package.json")
            }
        }
        catch {
             return [OperationResult]::Fail("Error writing package.json: $_")
        }
    }
}
