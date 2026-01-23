#
# Helper functions for npm operations
# These are outside classes because PowerShell classes have issues with external command output
#

function Invoke-NpmInstall {
    <#
    .SYNOPSIS
        Executes npm install in the specified directory with full UI
    .DESCRIPTION
        This function is outside the class because PowerShell classes
        don't properly display output from external commands like npm.
        This includes all UI rendering to ensure npm output is visible.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Repository
    )
    
    # Check if package.json exists
    $packageJsonPath = Join-Path $Repository.FullPath "package.json"
    if (-not (Test-Path $packageJsonPath)) {
        Clear-Host
        Write-Host "No package.json found in this repository." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return $false
    }
    
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "    INSTALL DEPENDENCIES" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Repository: " -NoNewline -ForegroundColor Yellow
    Write-Host $Repository.Name -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Running npm install..." -ForegroundColor Yellow
    Write-Host ""
    
    Push-Location $Repository.FullPath
    try {
        npm install
        Write-Host ""
        Write-Host "Dependencies installed successfully!" -ForegroundColor Green
        Start-Sleep -Seconds 2
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "Error installing dependencies: $_" -ForegroundColor Red
        Start-Sleep -Seconds 3
        return $false
    }
    finally {
        Pop-Location
    }
}

function Invoke-NpmRemoveNodeModules {
    <#
    .SYNOPSIS
        Removes node_modules folder
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$NodeModulesPath
    )
    
    try {
        Remove-Item -Path $NodeModulesPath -Recurse -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Error removing node_modules: $_"
        return $false
    }
}
