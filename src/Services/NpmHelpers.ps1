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
        Write-Host "No package.json found in this repository." -ForegroundColor ([Constants]::ColorError)
        Start-Sleep -Seconds 2
        return $false
    }
    
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "    INSTALL DEPENDENCIES" -ForegroundColor ([Constants]::ColorHeader)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
    Write-Host $Repository.Name -ForegroundColor ([Constants]::ColorValue)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host ""
    Write-Host "Running npm install..." -ForegroundColor ([Constants]::ColorWarning)
    Write-Host ""
    
    Push-Location $Repository.FullPath
    try {
        # Force npm output to be visible by calling it with explicit output redirection
        & npm install *>&1 | Write-Host
        Write-Host ""
        Write-Host "Dependencies installed successfully!" -ForegroundColor ([Constants]::ColorSuccess)
        Start-Sleep -Seconds 2
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "Error installing dependencies: $_" -ForegroundColor ([Constants]::ColorError)
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
