<#
.SYNOPSIS
    Installation script for repo-nav
.DESCRIPTION
    Interactive installer that configures repo-nav for your environment
#>

#region Functions
function Test-PowerShellProfile {
    if (Test-Path $PROFILE) {
        return $true
    }
    return $false
}

function New-PowerShellProfile {
    try {
        $profileDir = Split-Path -Parent $PROFILE
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        New-Item -Path $PROFILE -Type File -Force | Out-Null
        return $true
    }
    catch {
        Write-Host "Error creating profile: $_" -ForegroundColor Red
        return $false
    }
}

function Get-ReposPath {
    param([string]$scriptPath)
    
    Write-Host ""
    Write-Host "Enter the full path to your repositories folder:" -ForegroundColor Yellow
    Write-Host "Example: C:\Users\YourName\repos" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Path: " -NoNewline -ForegroundColor Cyan
    
    $reposPath = Read-Host
    
    # Trim whitespace
    $reposPath = $reposPath.Trim()
    
    # Validate path
    if ([string]::IsNullOrWhiteSpace($reposPath)) {
        Write-Host ""
        Write-Host "[ERROR] Path cannot be empty" -ForegroundColor Red
        return $null
    }
    
    if (-not (Test-Path $reposPath)) {
        Write-Host ""
        Write-Host "[ERROR] Path does not exist: $reposPath" -ForegroundColor Red
        return $null
    }
    
    # Normalize path
    $reposPath = (Resolve-Path $reposPath).Path
    
    Write-Host ""
    Write-Host "[OK] Path validated: $reposPath" -ForegroundColor Green
    
    return $reposPath
}

function Get-CommandAlias {
    Write-Host ""
    Write-Host "Choose a command name to launch repo-nav:" -ForegroundColor Yellow
    Write-Host "Default: list" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Command name (press Enter for 'list'): " -NoNewline -ForegroundColor Cyan
    
    $cmdName = Read-Host
    
    # Trim whitespace
    $cmdName = $cmdName.Trim()
    
    if ([string]::IsNullOrWhiteSpace($cmdName)) {
        $cmdName = "list"
    }
    
    # Validate command name
    if ($cmdName -notmatch '^[a-zA-Z][a-zA-Z0-9\-_]*$') {
        Write-Host ""
        Write-Host "[ERROR] Invalid command name. Must start with a letter and contain only letters, numbers, hyphens, or underscores." -ForegroundColor Red
        return $null
    }
    
    Write-Host ""
    Write-Host "[OK] Command name: $cmdName" -ForegroundColor Green
    
    return $cmdName
}

function Update-ProfileWithCommand {
    param(
        [string]$commandName,
        [string]$reposPath,
        [string]$scriptPath
    )
    
    # Build the command
    $repoNavPath = Join-Path $scriptPath "repo-nav.ps1"
    $command = "function $commandName { & '$repoNavPath' -BasePath '$reposPath' }"
    
    # Check if command already exists
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    
    if ($profileContent -match "function $commandName\s*\{") {
        Write-Host ""
        Write-Host "[WARNING] Function '$commandName' already exists in profile" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Do you want to replace it? (Y/n): " -NoNewline -ForegroundColor Cyan
        $response = Read-Host
        
        if ($response -ne '' -and $response -ne 'Y' -and $response -ne 'y') {
            Write-Host ""
            Write-Host "[INFO] Installation cancelled" -ForegroundColor Yellow
            return $false
        }
        
        # Remove old command (more robust regex)
        $profileContent = $profileContent -replace "(?ms)# Repository Navigator.*?function $commandName \{[^\}]+\}", ""
        $profileContent = $profileContent.Trim()
        Set-Content -Path $PROFILE -Value $profileContent
    }
    
    # Add new command
    Add-Content -Path $PROFILE -Value "`n"
    Add-Content -Path $PROFILE -Value "# Repository Navigator"
    Add-Content -Path $PROFILE -Value $command
    
    return $true
}

function Update-ConfigurationFiles {
    param(
        [string]$reposPath,
        [string]$scriptPath
    )
    
    # Update Constants.ps1
    $constantsPath = Join-Path $scriptPath "src\Config\Constants.ps1"
    $constantsContent = Get-Content $constantsPath -Raw
    
    # Replace the ReposBasePath
    $constantsContent = $constantsContent -replace 'static \[string\] \$ReposBasePath = ".*?"', "static [string] `$ReposBasePath = `"$reposPath`""
    
    # Update AliasFileName to include full path inside app
    $aliasFilePath = Join-Path $scriptPath ".repo-aliases.json"
    $constantsContent = $constantsContent -replace 'static \[string\] GetAliasFilePath\(\) \{[^}]+\}', @"
static [string] GetAliasFilePath() {
        return "$aliasFilePath"
    }
"@
    
    Set-Content -Path $constantsPath -Value $constantsContent
    
    Write-Host "[OK] Configuration updated" -ForegroundColor Green
}
#endregion

#region Main Installation
Clear-Host
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "    REPO-NAV INSTALLER" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This installer will:" -ForegroundColor White
Write-Host "  1. Configure your repositories path" -ForegroundColor Gray
Write-Host "  2. Choose a command name" -ForegroundColor Gray
Write-Host "  3. Add it to your PowerShell profile" -ForegroundColor Gray
Write-Host "  4. Update configuration files" -ForegroundColor Gray
Write-Host ""

# Get script location
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Step 1: Check/Create PowerShell profile
Write-Host "Step 1: Checking PowerShell profile..." -ForegroundColor Yellow
if (Test-PowerShellProfile) {
    Write-Host "[OK] PowerShell profile found" -ForegroundColor Green
    Write-Host "     Location: $PROFILE" -ForegroundColor DarkGray
} else {
    Write-Host "[INFO] PowerShell profile not found" -ForegroundColor Yellow
    Write-Host "       Creating profile..." -ForegroundColor Gray
    if (New-PowerShellProfile) {
        Write-Host "[OK] Profile created successfully" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ERROR] Failed to create profile. Exiting..." -ForegroundColor Red
        Start-Sleep -Seconds 3
        exit 1
    }
}

# Step 2: Get repositories path
Write-Host ""
Write-Host "Step 2: Configure repositories path" -ForegroundColor Yellow
$reposPath = Get-ReposPath -scriptPath $scriptPath

if (-not $reposPath) {
    Write-Host ""
    Write-Host "[ERROR] Invalid path. Installation cancelled." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# Step 3: Get command name
Write-Host ""
Write-Host "Step 3: Choose command name" -ForegroundColor Yellow
$commandName = Get-CommandAlias

if (-not $commandName) {
    Write-Host ""
    Write-Host "[ERROR] Invalid command name. Installation cancelled." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

# Step 4: Update PowerShell profile
Write-Host ""
Write-Host "Step 4: Updating PowerShell profile..." -ForegroundColor Yellow

if (-not (Update-ProfileWithCommand -commandName $commandName -reposPath $reposPath -scriptPath $scriptPath)) {
    Write-Host ""
    Write-Host "[ERROR] Failed to update profile. Exiting..." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

Write-Host "[OK] Profile updated successfully" -ForegroundColor Green

# Step 5: Update configuration files
Write-Host ""
Write-Host "Step 5: Updating configuration files..." -ForegroundColor Yellow
Update-ConfigurationFiles -reposPath $reposPath -scriptPath $scriptPath

# Move alias file if exists
$oldAliasPath = Join-Path $reposPath ".repo-aliases.json"
$newAliasPath = Join-Path $scriptPath ".repo-aliases.json"

if ((Test-Path $oldAliasPath) -and ($oldAliasPath -ne $newAliasPath)) {
    Write-Host ""
    Write-Host "[INFO] Found existing aliases file" -ForegroundColor Yellow
    Write-Host "       Moving to app folder..." -ForegroundColor Gray
    Move-Item -Path $oldAliasPath -Destination $newAliasPath -Force
    Write-Host "[OK] Aliases file moved" -ForegroundColor Green
}

# Final message
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "    INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor White
Write-Host "  Repositories: " -NoNewline -ForegroundColor Gray
Write-Host $reposPath -ForegroundColor Yellow
Write-Host "  Command:      " -NoNewline -ForegroundColor Gray
Write-Host $commandName -ForegroundColor Green
Write-Host "  App location: " -NoNewline -ForegroundColor Gray
Write-Host $scriptPath -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Reload your profile:" -ForegroundColor Gray
Write-Host "     . `$PROFILE" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Or restart PowerShell" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Then type: " -NoNewline -ForegroundColor Gray
Write-Host $commandName -ForegroundColor Green
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#endregion
