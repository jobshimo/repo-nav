#
# Helper functions for npm operations
# These are outside classes because PowerShell classes have issues with external command output
#

function Get-NpmExecutablePath {
    <#
    .SYNOPSIS
        Smart detection of npm executable, handling NVM and missing PATH entries
    #>
    
    # 1. Try standard discovery via PATH
    if (Get-Command "npm" -ErrorAction SilentlyContinue) {
        return "npm"
    }

    # 2. Check NVM Symlink environment variable
    if ($env:NVM_SYMLINK -and (Test-Path "$env:NVM_SYMLINK\npm.cmd")) {
        return "$env:NVM_SYMLINK\npm.cmd"
    }

    # 3. Check standard NodeJS installation path (common for NVM symlink too)
    $programsPath = [Environment]::GetFolderPath("ProgramFiles")
    $standardNode = Join-Path $programsPath "nodejs\npm.cmd"
    if (Test-Path $standardNode) {
        return $standardNode
    }

    # 4. Smart NVM Fallback: Look for installed versions in NVM_HOME
    # This handles cases where NVM is installed but 'nvm use' hasn't been run or symlink is broken
    if ($env:NVM_HOME -and (Test-Path $env:NVM_HOME)) {
        try {
            # Find directories starting with 'v' (e.g., v14.17.0, v16.0.0)
            # Sort by Name descending to try get the latest version roughly
            # (String sort isn't perfect for semver but good enough as fallback)
            $latestVersion = Get-ChildItem -Path $env:NVM_HOME -Directory -Filter "v*" | 
                             Sort-Object Name -Descending | 
                             Select-Object -First 1
                             
            if ($latestVersion) {
                $nvmNpmPath = Join-Path $latestVersion.FullName "npm.cmd"
                # Some NVM versions put npm inside node_modules/npm/bin (rarer on Windows but possible)
                
                if (Test-Path $nvmNpmPath) {
                    return $nvmNpmPath
                }
            }
        }
        catch {
            # Ignore errors during fallback search
        }
    }

    return $null
}

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
        $Repository,

        [Parameter(Mandatory = $false)]
        $LocalizationService,

        [Parameter(Mandatory = $false)]
        $Console
    )
    
    # helper for localization
    function Get-Loc([string]$key, [string]$default) {
        if ($LocalizationService) { return $LocalizationService.Get($key) }
        return $default
    }

    # Hide cursor helper that handles missing ConsoleHelper
    function Hide-Cursor {
        if ($Console) { $Console.HideCursor() }
        else { try { [Console]::CursorVisible = $false } catch {} }
    }

    function Show-Cursor {
        if ($Console) { $Console.ShowCursor() }
        else { try { [Console]::CursorVisible = $true } catch {} }
    }

    # Check if package.json exists
    $packageJsonPath = Join-Path $Repository.FullPath "package.json"
    if (-not (Test-Path $packageJsonPath)) {
        Clear-Host
        Write-Host $(Get-Loc "Error.Repo.NoPackageJson" "No package.json found in this repository.") -ForegroundColor ([Constants]::ColorError)
        Start-Sleep -Seconds 2
        return $false
    }

    # Check if npm is available using smart detection
    $npmPath = Get-NpmExecutablePath
    
    if (-not $npmPath) {
        Clear-Host
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    MISSING DEPENDENCY" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
        Write-Host $(Get-Loc "Error.Npm.NotFound" "Error: 'npm' command was not found in your PATH or standard locations.") -ForegroundColor ([Constants]::ColorError)
        Write-Host ""
        Write-Host $(Get-Loc "Error.Npm.InstallNode" "To use this feature, you need to install Node.js.") -ForegroundColor ([Constants]::ColorWarning)
        Write-Host $(Get-Loc "Error.Npm.InstallLink" "Please download and install it from: https://nodejs.org/") -ForegroundColor ([Constants]::ColorValue)
        Write-Host $(Get-Loc "Error.Npm.NvmHint" "If you use NVM, ensure a version is currently selected ('nvm use ...').") -ForegroundColor ([Constants]::ColorGray)
        Write-Host ""
        Start-Sleep -Seconds 5
        return $false
    }
    
    Clear-Host
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host ("    " + $(Get-Loc "Msg.Npm.Installing" "INSTALL DEPENDENCIES")) -ForegroundColor ([Constants]::ColorHeader)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
    Write-Host $Repository.Name -ForegroundColor ([Constants]::ColorValue)
    Write-Host "=======================================================" -ForegroundColor ([Constants]::ColorSeparator)
    Write-Host ""
    
    # Show brief animated "preparing" message
    $cursorPos = $host.UI.RawUI.CursorPosition
    $dotCount = 0
    $iterations = 0
    $maxIterations = 5  # Show animation for ~2 seconds
    
    $locRunMsg = Get-Loc "Msg.Npm.RunningInstall" "Running npm install"

    while ($iterations -lt $maxIterations) {
        # Restore cursor position
        $host.UI.RawUI.CursorPosition = $cursorPos
        
        # Create the dots string (0 to 3 dots)
        $dots = "." * $dotCount
        
        # Display progress indicator
        $message = $locRunMsg + $dots
        Write-Host $message.PadRight(50) -NoNewline -ForegroundColor ([Constants]::ColorWarning)
        
        # Increment dot count and cycle back to 0 after 3 dots
        $dotCount = ($dotCount + 1) % 4
        $iterations++
        
        Start-Sleep -Milliseconds 400
    }
    
    # Leave the final static message visible
    $host.UI.RawUI.CursorPosition = $cursorPos
    Write-Host ($locRunMsg + "...").PadRight(50) -ForegroundColor ([Constants]::ColorWarning)
    Write-Host ""
    
    Push-Location $Repository.FullPath
    try {
        # Ensure cursor is visible for npm output (some tools might expect it)
        Show-Cursor

        # Force npm output to be visible by calling it with explicit output redirection
        # Use invocation operator & with the resolved path
        & $npmPath install *>&1 | Write-Host
        
        # Hide cursor immediately after npm finishes
        Hide-Cursor
        
        Write-Host ""
        Write-Host $(Get-Loc "Msg.Npm.Success" "Dependencies installed successfully!") -ForegroundColor ([Constants]::ColorSuccess)
        Start-Sleep -Seconds 2
        return $true
    }
    catch {
        Hide-Cursor
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
        Removes node_modules folder with visual progress indicator
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$NodeModulesPath
    )
    
    try {
        # Save cursor position
        $cursorPos = $host.UI.RawUI.CursorPosition
        
        # Start the removal in a background job
        $job = Start-Job -ScriptBlock {
            param($path)
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        } -ArgumentList $NodeModulesPath
        
        # Show animated progress while job runs
        $dotCount = 0
        $maxDots = 3
        while ($job.State -eq 'Running') {
            # Restore cursor position
            $host.UI.RawUI.CursorPosition = $cursorPos
            
            # Create the dots string (0 to 3 dots)
            $dots = "." * $dotCount
            
            # Display progress indicator with padding to clear previous text
            $message = "Removing node_modules" + $dots
            Write-Host $message.PadRight(50) -NoNewline -ForegroundColor ([Constants]::ColorWarning)
            
            # Increment dot count and cycle back to 0 after maxDots
            $dotCount = ($dotCount + 1) % ($maxDots + 1)
            
            Start-Sleep -Milliseconds 400
        }
        
        # Wait for job to complete and get result
        $jobResult = Wait-Job -Job $job
        $jobError = Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable jobErrors
        Remove-Job -Job $job
        
        # Clear the progress line
        $host.UI.RawUI.CursorPosition = $cursorPos
        Write-Host (" " * 50) -NoNewline
        $host.UI.RawUI.CursorPosition = $cursorPos
        
        if ($jobResult.State -eq 'Completed' -and $jobErrors.Count -eq 0) {
            return $true
        }
        else {
            Write-Error "Error removing node_modules: $($jobErrors -join '; ')"
            return $false
        }
    }
    catch {
        Write-Error "Error removing node_modules: $_"
        return $false
    }
}
