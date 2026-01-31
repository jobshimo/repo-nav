<#
.SYNOPSIS
    Installs the pre-commit hook for repo-nav
    
.DESCRIPTION
    Copies the pre-commit hook script to .git/hooks/pre-commit
    
.EXAMPLE
    .\Install-PreCommitHook.ps1
#>

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path $PSScriptRoot -Parent
$gitHooksDir = Join-Path $scriptRoot ".git\hooks"
$hookSource = Join-Path $PSScriptRoot "Install-GitHook.ps1"
$hookDestination = Join-Path $gitHooksDir "pre-commit"

Write-Host ""
Write-Host "Installing pre-commit hook..." -ForegroundColor Cyan

if (-not (Test-Path $gitHooksDir)) {
    Write-Host "  ERROR: .git/hooks directory not found" -ForegroundColor Red
    Write-Host "  Are you in a git repository?" -ForegroundColor Yellow
    exit 1
}

try {
    # Create a bash wrapper for the PowerShell hook
    $hookContent = @'
#!/bin/sh
# Pre-commit hook wrapper for repo-nav

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/scripts/Install-GitHook.ps1"

# Run PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOOK_SCRIPT"
exit $?
'@

    $hookContent | Out-File -FilePath $hookDestination -Encoding ASCII -NoNewline
    
    Write-Host "  OK: Pre-commit hook installed" -ForegroundColor Green
    Write-Host ""
    Write-Host "  The hook will run automatically before each commit" -ForegroundColor Gray
    Write-Host "  To bypass: git commit --no-verify" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "  ERROR: Failed to install hook" -ForegroundColor Red
    Write-Host "  Details: $_" -ForegroundColor Yellow
    exit 1
}
