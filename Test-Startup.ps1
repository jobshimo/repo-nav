<#
.SYNOPSIS
    Test-Startup.ps1 - Verifies that the application types load correctly.
#>

$ErrorActionPreference = "Stop"

Write-Host "Starting Smoke Test..." -ForegroundColor Cyan

# Define the root path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$srcPath = Join-Path $scriptPath "src"

Write-Host "Source Path: $srcPath" -ForegroundColor Gray

try {
    # 1. Simulate the loading order from repo-nav.ps1
    # Note: We are NOT running repo-nav.ps1 because it starts the UI loop.
    # We just want to source the files in order to check for parse errors.

    $filesToLoad = @(
        "Core/Common/OperationResult.ps1",
        "Models/GitStatusModel.ps1",
        "Models/AliasInfo.ps1",
        "Models/RepositoryModel.ps1",
        "Services/GitReadService.ps1",
        "Services/GitWriteService.ps1",
        "Services/GitService.ps1" 
    )

    foreach ($file in $filesToLoad) {
        $fullPath = Join-Path $srcPath $file
        Write-Host "Testing load: $file" -NoNewline
        . $fullPath
        Write-Host " [OK]" -ForegroundColor Green
    }

    # now try to load the main entry point (but stop before execution if possible, 
    # or just rely on the fact that if GitService is broken, the above would fail depending on how I load it)
    
    # Actually, a better test is to just try to parse the file without executing?
    # Or just source the main app builder.
    
    Write-Host "Smoke Test Passed!" -ForegroundColor Green
}
catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
