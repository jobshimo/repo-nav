<#
.SYNOPSIS
    Setup wizard for repo-nav
.DESCRIPTION
    Interactive setup that configures repo-nav for your environment.
    Checks system requirements, configures paths, and sets up PowerShell profile.
    
    Can be re-run at any time to reconfigure settings.
.NOTES
    Author: Martin Miguel Bernal Garcia
    Requires: PowerShell 5.1+
#>

#region Constants
$script:UI_WIDTH = 90
$script:REQUIRED_PS_VERSION = [Version]"5.1"
$script:SYMBOLS = @{
    Check    = [char]0x2713  # ✓
    Cross    = [char]0x2717  # ✗
    Warning  = [char]0x26A0  # ⚠
    Arrow    = [char]0x25B6  # ▶
    Folder   = [char]0x1F4C1 # 📁 (fallback to text if not supported)
    Gear     = [char]0x2699  # ⚙
}
#endregion

#region UI Helpers
function Write-SetupHeader {
    Clear-Host
    $ascii = @"

    ██████╗ ███████╗██████╗  ██████╗       ███╗   ██╗ █████╗ ██╗   ██╗
    ██╔══██╗██╔════╝██╔══██╗██╔═══██╗      ████╗  ██║██╔══██╗██║   ██║
    ██████╔╝█████╗  ██████╔╝██║   ██║█████╗██╔██╗ ██║███████║██║   ██║
    ██╔══██╗██╔══╝  ██╔═══╝ ██║   ██║╚════╝██║╚██╗██║██╔══██║╚██╗ ██╔╝
    ██║  ██║███████╗██║     ╚██████╔╝      ██║ ╚████║██║  ██║ ╚████╔╝ 
    ╚═╝  ╚═╝╚══════╝╚═╝      ╚═════╝       ╚═╝  ╚═══╝╚═╝  ╚═╝  ╚═══╝ 
                                                                      
"@
    Write-Host $ascii -ForegroundColor Cyan
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Cyan
    Write-Host "    S E T U P   W I Z A R D" -ForegroundColor White
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Cyan
    Write-Host ""
}

function Write-StepHeader {
    param([string]$Title, [int]$Step, [int]$Total)
    
    Write-Host ""
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Cyan
    Write-Host "    STEP $Step/$Total : $Title" -ForegroundColor White
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Box {
    param(
        [string]$Title,
        [string[]]$Lines,
        [ConsoleColor]$BorderColor = "DarkGray"
    )
    
    $innerWidth = $script:UI_WIDTH - 4
    
    Write-Host ""
    Write-Host ("+" + ("-" * ($script:UI_WIDTH - 2)) + "+") -ForegroundColor $BorderColor
    Write-Host ("|  " + $Title.PadRight($innerWidth) + "|") -ForegroundColor $BorderColor
    Write-Host ("+" + ("-" * ($script:UI_WIDTH - 2)) + "+") -ForegroundColor $BorderColor
    
    foreach ($line in $Lines) {
        Write-Host "|  " -NoNewline -ForegroundColor $BorderColor
        Write-Host $line.PadRight($innerWidth) -NoNewline
        Write-Host "|" -ForegroundColor $BorderColor
    }
    
    Write-Host ("+" + ("-" * ($script:UI_WIDTH - 2)) + "+") -ForegroundColor $BorderColor
    Write-Host ""
}

function Write-Status {
    param(
        [string]$Label,
        [string]$Value,
        [ValidateSet("Success", "Warning", "Error", "Info")]
        [string]$Status = "Info"
    )
    
    $symbol = switch ($Status) {
        "Success" { $script:SYMBOLS.Check }
        "Warning" { "!" }
        "Error"   { $script:SYMBOLS.Cross }
        "Info"    { "-" }
    }
    
    $symbolColor = switch ($Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Info"    { "Gray" }
    }
    
    Write-Host "  [" -NoNewline -ForegroundColor DarkGray
    Write-Host $symbol -NoNewline -ForegroundColor $symbolColor
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $Label.PadRight(20) -NoNewline -ForegroundColor Gray
    Write-Host $Value -ForegroundColor $symbolColor
}

function Write-Option {
    param(
        [int]$Number,
        [string]$Text,
        [string]$Hint = "",
        [bool]$IsSelected = $false
    )
    
    $prefix = if ($IsSelected) { "  $($script:SYMBOLS.Arrow) " } else { "    " }
    
    Write-Host $prefix -NoNewline -ForegroundColor Cyan
    Write-Host "[$Number] " -NoNewline -ForegroundColor Yellow
    Write-Host $Text -NoNewline -ForegroundColor White
    
    if ($Hint) {
        Write-Host "  $Hint" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

function Write-Prompt {
    param([string]$Text)
    Write-Host ""
    Write-Host "  $Text " -NoNewline -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "  [$($script:SYMBOLS.Check)] $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "  [!] $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "  [$($script:SYMBOLS.Cross)] $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [-] $Text" -ForegroundColor Gray
}

function Read-ValidatedInput {
    param(
        [string]$Prompt,
        [string]$Default = "",
        [scriptblock]$Validator = { $true },
        [string]$ErrorMessage = "Invalid input"
    )
    
    while ($true) {
        Write-Prompt $Prompt
        if ($Default) {
            Write-Host "(default: $Default) " -NoNewline -ForegroundColor DarkGray
        }
        
        $input = Read-Host
        $input = $input.Trim()
        
        if ([string]::IsNullOrWhiteSpace($input) -and $Default) {
            $input = $Default
        }
        
        if (& $Validator $input) {
            return $input
        }
        
        Write-Error $ErrorMessage
    }
}
#endregion

#region System Checks
function Test-SystemRequirements {
    Write-StepHeader "SYSTEM CHECK" 1 4
    
    $results = @{
        PowerShell = @{ OK = $false; Version = ""; Message = "" }
        Git        = @{ OK = $false; Version = ""; Message = "" }
        Npm        = @{ OK = $false; Version = ""; Message = "" }
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    $results.PowerShell.Version = $psVersion.ToString()
    
    if ($psVersion -ge $script:REQUIRED_PS_VERSION) {
        $results.PowerShell.OK = $true
        $results.PowerShell.Message = "OK"
    } else {
        $results.PowerShell.OK = $false
        $results.PowerShell.Message = "Version $($script:REQUIRED_PS_VERSION)+ required"
    }
    
    # Check Git
    try {
        $gitVersion = & git --version 2>$null
        if ($gitVersion -match "git version ([\d\.]+)") {
            $results.Git.OK = $true
            $results.Git.Version = $Matches[1]
            $results.Git.Message = "OK"
        }
    } catch {
        $results.Git.OK = $false
        $results.Git.Version = "Not found"
        $results.Git.Message = "Git operations will be disabled"
    }
    
    if (-not $results.Git.OK) {
        $results.Git.Version = "Not found"
    }
    
    # Check npm
    try {
        $npmVersion = & npm --version 2>$null
        if ($npmVersion) {
            $results.Npm.OK = $true
            $results.Npm.Version = $npmVersion.Trim()
            $results.Npm.Message = "OK"
        }
    } catch {
        $results.Npm.OK = $false
        $results.Npm.Version = "Not found"
        $results.Npm.Message = "npm operations will be disabled"
    }
    
    if (-not $results.Npm.OK) {
        $results.Npm.Version = "Not found"
    }
    
    # Display results
    Write-Box "SYSTEM REQUIREMENTS" @(
        "",
        "  Checking your system for required dependencies...",
        ""
    )
    
    # PowerShell
    if ($results.PowerShell.OK) {
        Write-Status "PowerShell" "v$($results.PowerShell.Version)" "Success"
    } else {
        Write-Status "PowerShell" "v$($results.PowerShell.Version) - REQUIRED 5.1+" "Error"
    }
    
    # Git
    if ($results.Git.OK) {
        Write-Status "Git" "v$($results.Git.Version)" "Success"
    } else {
        Write-Status "Git" "Not found (optional)" "Warning"
    }
    
    # npm
    if ($results.Npm.OK) {
        Write-Status "npm" "v$($results.Npm.Version)" "Success"
    } else {
        Write-Status "npm" "Not found (optional)" "Warning"
    }
    
    Write-Host ""
    
    # Warnings
    if (-not $results.Git.OK) {
        Write-Warning "Git not found. Clone and status features will be disabled."
        Write-Info "Install Git from: https://git-scm.com/downloads"
        Write-Host ""
    }
    
    if (-not $results.Npm.OK) {
        Write-Warning "npm not found. Package management features will be disabled."
        Write-Info "Install Node.js from: https://nodejs.org/"
        Write-Host ""
    }
    
    # Critical check - PowerShell version
    if (-not $results.PowerShell.OK) {
        Write-Host ""
        Write-Error "PowerShell 5.1 or higher is required for repo-nav."
        Write-Error "Please upgrade PowerShell and run setup again."
        Write-Host ""
        Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    
    Write-Success "System check passed!"
    Write-Host ""
    Start-Sleep -Milliseconds 500
    
    return $results
}
#endregion

#region Path Configuration
function Get-RepositoriesPath {
    param([string]$ScriptPath)
    
    Write-StepHeader "REPOSITORIES PATH" 2 4
    
    # Calculate potential paths
    $parentPath = Split-Path -Parent $ScriptPath
    $currentPath = $ScriptPath
    
    Write-Host "  Where are your Git repositories located?" -ForegroundColor White
    Write-Host ""
    
    Write-Option 1 "Parent folder" $parentPath
    Write-Option 2 "Custom path" "Enter a different location"
    Write-Option 3 "Current folder" $currentPath
    
    Write-Host ""
    
    $choice = Read-ValidatedInput "Select option (1-3):" "1" {
        param($v) $v -match "^[123]$"
    } "Please enter 1, 2, or 3"
    
    $selectedPath = switch ($choice) {
        "1" { $parentPath }
        "2" { 
            Write-Host ""
            $customPath = Read-ValidatedInput "Enter full path:" "" {
                param($v) 
                if ([string]::IsNullOrWhiteSpace($v)) { return $false }
                return Test-Path $v
            } "Path does not exist. Please enter a valid path."
            $customPath
        }
        "3" { $currentPath }
    }
    
    # Normalize path
    $selectedPath = (Resolve-Path $selectedPath).Path
    
    Write-Host ""
    Write-Success "Path configured: $selectedPath"
    Write-Host ""
    Start-Sleep -Milliseconds 300
    
    return $selectedPath
}
#endregion

#region Command Configuration
function Get-CommandName {
    Write-StepHeader "COMMAND NAME" 3 4
    
    Write-Host "  Choose a command name to launch repo-nav from any terminal." -ForegroundColor White
    Write-Host ""
    Write-Host "  Examples: " -NoNewline -ForegroundColor Gray
    Write-Host "list" -NoNewline -ForegroundColor Green
    Write-Host ", " -NoNewline -ForegroundColor Gray
    Write-Host "repos" -NoNewline -ForegroundColor Cyan
    Write-Host ", " -NoNewline -ForegroundColor Gray
    Write-Host "nav" -ForegroundColor Yellow
    Write-Host ""
    
    $commandName = Read-ValidatedInput "Command name:" "list" {
        param($v)
        if ([string]::IsNullOrWhiteSpace($v)) { return $false }
        return $v -match "^[a-zA-Z][a-zA-Z0-9\-_]*$"
    } "Invalid name. Use letters, numbers, hyphens or underscores. Must start with a letter."
    
    Write-Host ""
    Write-Success "Command configured: $commandName"
    Write-Host ""
    Start-Sleep -Milliseconds 300
    
    return $commandName
}
#endregion

#region Profile Management
function Update-PowerShellProfile {
    param(
        [string]$CommandName,
        [string]$ReposPath,
        [string]$ScriptPath
    )
    
    Write-StepHeader "PROFILE SETUP" 4 4
    
    # Check if profile exists
    Write-Info "Checking PowerShell profile..."
    
    if (-not (Test-Path $PROFILE)) {
        Write-Warning "Profile not found. Creating new profile..."
        
        $profileDir = Split-Path -Parent $PROFILE
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
        
        Write-Success "Profile created: $PROFILE"
    } else {
        Write-Success "Profile found: $PROFILE"
    }
    
    # Build the command
    $repoNavPath = Join-Path $ScriptPath "repo-nav.ps1"
    $functionCode = "function $CommandName { & '$repoNavPath' -BasePath '$ReposPath' }"
    
    # Check if function already exists
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    
    if ($profileContent -match "function $CommandName\s*\{") {
        Write-Warning "Function '$CommandName' already exists in profile."
        Write-Host ""
        Write-Prompt "Replace existing function? (Y/n):"
        $response = Read-Host
        
        if ($response -ne '' -and $response -notin @('Y', 'y', 'yes', 'Yes')) {
            Write-Info "Keeping existing function. Setup complete."
            return $false
        }
        
        # Remove old function block
        $profileContent = $profileContent -replace "(?ms)# repo-nav command[^\n]*\nfunction $CommandName \{[^\}]+\}\n?", ""
        $profileContent = $profileContent.Trim()
        Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8
    }
    
    # Add new function
    $blockToAdd = @"

# repo-nav command
$functionCode
"@
    
    Add-Content -Path $PROFILE -Value $blockToAdd -Encoding UTF8
    
    Write-Success "Profile updated successfully!"
    Write-Host ""
    
    return $true
}
#endregion

#region Configuration Files
function Update-ConfigurationFiles {
    param(
        [string]$ReposPath,
        [string]$ScriptPath
    )
    
    Write-Info "Updating configuration files..."
    
    # Create .repo-config.json
    $configPath = Join-Path $ScriptPath ".repo-config.json"
    
    # Extract username from path or use current user
    $userName = $env:USERNAME
    if ($ReposPath -match '\\Users\\([^\\]+)\\') {
        $userName = $Matches[1]
    }
    
    $config = @{
        reposBasePath = $ReposPath
        userName = $userName
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
    
    Write-Success "Configuration saved: .repo-config.json"
    
    # Handle existing alias file migration
    $oldAliasPath = Join-Path $ReposPath ".repo-aliases.json"
    $newAliasPath = Join-Path $ScriptPath ".repo-aliases.json"
    
    if ((Test-Path $oldAliasPath) -and ($oldAliasPath -ne $newAliasPath)) {
        Write-Info "Found existing aliases file. Migrating..."
        Move-Item -Path $oldAliasPath -Destination $newAliasPath -Force
        Write-Success "Aliases migrated to app folder."
    }
}
#endregion

#region Summary
function Show-Summary {
    param(
        [string]$CommandName,
        [string]$ReposPath,
        [string]$ScriptPath,
        [hashtable]$SystemResults
    )
    
    Write-Host ""
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Green
    Write-Host "    SETUP COMPLETE!" -ForegroundColor Green
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Green
    Write-Host ""
    
    # Configuration Summary
    Write-Box "CONFIGURATION SUMMARY" @(
        "",
        "  Repositories:  $ReposPath",
        "  Command:       $CommandName",
        "  App location:  $ScriptPath",
        ""
    ) -BorderColor Cyan
    
    # Feature availability
    $gitStatus = if ($SystemResults.Git.OK) { "Enabled" } else { "Disabled (Git not found)" }
    $npmStatus = if ($SystemResults.Npm.OK) { "Enabled" } else { "Disabled (npm not found)" }
    
    Write-Box "FEATURE STATUS" @(
        "",
        "  Navigation & Aliases    Always available",
        "  Git operations          $gitStatus",
        "  npm operations          $npmStatus",
        ""
    ) -BorderColor DarkGray
    
    # Next steps
    Write-Host ""
    Write-Host "  NEXT STEPS" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Reload your profile:" -ForegroundColor White
    Write-Host "     " -NoNewline
    Write-Host ". `$PROFILE" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Or simply restart your terminal" -ForegroundColor White
    Write-Host ""
    Write-Host "  3. Launch repo-nav:" -ForegroundColor White
    Write-Host "     " -NoNewline
    Write-Host $CommandName -ForegroundColor Green
    Write-Host ""
    Write-Host ("=" * $script:UI_WIDTH) -ForegroundColor Cyan
    Write-Host ""
}
#endregion

#region Main
function Start-Setup {
    # Get script location
    $scriptPath = Split-Path -Parent $MyInvocation.PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $PSScriptRoot
    }
    if (-not $scriptPath) {
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    
    # Show header
    Write-SetupHeader
    
    Write-Host "  Welcome to repo-nav setup!" -ForegroundColor White
    Write-Host ""
    Write-Host "  This wizard will:" -ForegroundColor Gray
    Write-Host "    - Check system requirements" -ForegroundColor DarkGray
    Write-Host "    - Configure your repositories path" -ForegroundColor DarkGray
    Write-Host "    - Set up your PowerShell profile" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Press " -NoNewline -ForegroundColor Gray
    Write-Host "Enter" -NoNewline -ForegroundColor Yellow
    Write-Host " to continue or " -NoNewline -ForegroundColor Gray
    Write-Host "Ctrl+C" -NoNewline -ForegroundColor Red
    Write-Host " to cancel..." -ForegroundColor Gray
    Read-Host
    
    try {
        # Step 1: System checks
        $systemResults = Test-SystemRequirements
        
        # Step 2: Get repositories path
        $reposPath = Get-RepositoriesPath -ScriptPath $scriptPath
        
        # Step 3: Get command name
        $commandName = Get-CommandName
        
        # Step 4: Update profile
        $profileUpdated = Update-PowerShellProfile -CommandName $commandName -ReposPath $reposPath -ScriptPath $scriptPath
        
        # Update config files
        Update-ConfigurationFiles -ReposPath $reposPath -ScriptPath $scriptPath
        
        # Show summary
        Show-Summary -CommandName $commandName -ReposPath $reposPath -ScriptPath $scriptPath -SystemResults $systemResults
        
    } catch {
        Write-Host ""
        Write-Error "Setup failed: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "  Stack trace:" -ForegroundColor DarkGray
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run setup
Start-Setup
#endregion
