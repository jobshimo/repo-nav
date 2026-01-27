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
            Remove-Item -Path $nodeModulesPath -Recurse -Force -ErrorAction Stop
            
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
            catch {}
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
    # Uses 'npm version' if available to ensure package-lock.json sync
    # Fallback to manual JSON edit if npm is missing
    [hashtable] SetVersion([string]$repoPath, [string]$newVersion) {
        if (-not $this.HasPackageJson($repoPath)) {
            return @{ Success = $false; Output = "No package.json found" }
        }
        
        # 1. Try with npm executable (Preferred way - handles package-lock.json automatically)
        $npmPath = $this.GetNpmExecutablePath()
        if (-not [string]::IsNullOrWhiteSpace($npmPath)) {
            try {
                $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
                $processInfo.FileName = $npmPath
                # --no-git-tag-version: We handle git operations separately in the flow
                # --allow-same-version: Prevent error if version is same
                $processInfo.Arguments = "version $newVersion --no-git-tag-version --allow-same-version"
                $processInfo.WorkingDirectory = $repoPath
                $processInfo.RedirectStandardOutput = $true
                $processInfo.RedirectStandardError = $true
                $processInfo.UseShellExecute = $false
                $processInfo.CreateNoWindow = $true
                $processInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                $processInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
                
                $process = [System.Diagnostics.Process]::Start($processInfo)
                $process.WaitForExit()
                
                $stdout = $process.StandardOutput.ReadToEnd()
                $stderr = $process.StandardError.ReadToEnd()
                
                if ($process.ExitCode -eq 0) {
                    return @{ Success = $true; Output = "Updated to $newVersion via npm" }
                } else {
                    Write-Warning "npm version failed: $stderr"
                    # Fallthrough to manual method
                }
            }
            catch {
                Write-Warning "Error executing npm: $_"
                # Fallthrough to manual method
            }
        }
        
        # 2. Fallback: Manual JSON manipulation
        # Note: This might desync package-lock.json if it exists!
        try {
            $packageJsonPath = Join-Path $repoPath "package.json"
            $content = Get-Content $packageJsonPath -Raw
            
            # Regex replace to preserve formatting as much as possible
            # Looks for "version": "..."
            if ($content -match '"version"\s*:\s*"[^"]+"') {
                $newContent = $content -replace '"version"\s*:\s*"[^"]+"', """version"": ""$newVersion"""
                Set-Content -Path $packageJsonPath -Value $newContent -Encoding UTF8
                
                $msg = "Updated package.json manually to $newVersion"
                
                # Check package-lock.json warning
                if ($this.HasPackageLock($repoPath)) {
                    $msg += ". WARNING: package-lock.json content was NOT updated."
                }
                
                return @{ Success = $true; Output = $msg }
            } else {
                 return @{ Success = $false; Output = "Could not find version field in package.json" }
            }
        }
        catch {
             return @{ Success = $false; Output = "Error writing package.json: $_" }
        }
    }
}
