<#
.SYNOPSIS
    Test script for Phase 1 components
    
.DESCRIPTION
    Tests the infrastructure created in Phase 1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PHASE 1 COMPONENT TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$TestCount = 0

# Helper function
function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$TestBlock
    )
    
    $script:TestCount++
    Write-Host "Test $($script:TestCount): " -NoNewline
    Write-Host $Name -ForegroundColor Yellow
    
    try {
        & $TestBlock
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        Write-Host ""
        return $true
    }
    catch {
        Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
        if ($_.ScriptStackTrace) {
            Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
        }
        Write-Host ""
        $script:ErrorCount++
        return $false
    }
}

# Load dependencies
Write-Host "Loading dependencies..." -ForegroundColor Gray
try {
    . "$PSScriptRoot\src\Config\Constants.ps1"
    . "$PSScriptRoot\src\Models\RepositoryModel.ps1"
    . "$PSScriptRoot\src\Models\GitStatusModel.ps1"
    . "$PSScriptRoot\src\Models\AliasInfo.ps1"
    Write-Host "✓ Dependencies loaded" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to load dependencies: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

#region Test 1: INavigationCommand loads
Test-Component "INavigationCommand interface loads" {
    . "$PSScriptRoot\src\Core\Commands\INavigationCommand.ps1"
    
    if ($null -eq [INavigationCommand]) {
        throw "Class not found"
    }
}
#endregion

#region Test 2: NavigationState loads and works
Test-Component "NavigationState creation and methods" {
    . "$PSScriptRoot\src\Core\NavigationState.ps1"
    
    # Create mock repositories
    $mockRepos = @(
        [RepositoryModel]::new("Repo1", "C:\Test\Repo1"),
        [RepositoryModel]::new("Repo2", "C:\Test\Repo2"),
        [RepositoryModel]::new("Repo3", "C:\Test\Repo3")
    )
    
    # Create state
    $state = [NavigationState]::new($mockRepos)
    
    # Test initial state
    if ($state.SelectedIndex -ne 0) { throw "Initial index should be 0" }
    if ($state.GetTotalCount() -ne 3) { throw "Total count should be 3" }
    if (-not $state.IsRunning) { throw "Should be running initially" }
    
    # Test navigation
    $state.SelectNext()
    if ($state.SelectedIndex -ne 1) { throw "Should be at index 1" }
    
    $state.SelectPrevious()
    if ($state.SelectedIndex -ne 0) { throw "Should be back at index 0" }
    
    # Test wraparound
    $state.SelectPrevious()
    if ($state.SelectedIndex -ne 2) { throw "Should wrap to index 2" }
    
    # Test stop
    $state.Stop()
    if ($state.IsRunning) { throw "Should not be running after Stop" }
    
    # Test redraw flags
    $state.MarkForFullRedraw()
    if (-not $state.RequiresFullRedraw) { throw "Should require full redraw" }
    
    $state.ClearRedrawFlags()
    if ($state.RequiresFullRedraw) { throw "Flags should be cleared" }
}
#endregion

#region Test 3: ExitCommand
Test-Component "ExitCommand creation and execution" {
    . "$PSScriptRoot\src\Core\Commands\ExitCommand.ps1"
    . "$PSScriptRoot\src\Core\NavigationState.ps1"
    
    # Create mock dependencies
    $mockConsole = [PSCustomObject]@{
        ClearScreen = { }
    }
    
    $mockRenderer = [PSCustomObject]@{
        RenderWarning = { param($msg) }
    }
    
    # Create command
    $cmd = [ExitCommand]::new($mockConsole, $mockRenderer)
    
    # Create state
    $mockRepos = @([RepositoryModel]::new("Test", "C:\Test"))
    $state = [NavigationState]::new($mockRepos)
    
    # Test CanExecute
    if (-not $cmd.CanExecute($state)) { throw "ExitCommand should always be able to execute" }
    
    # Test Execute
    $cmd.Execute($state, @{})
    if ($state.IsRunning) { throw "State should be stopped after Execute" }
    
    # Test Description
    $desc = $cmd.GetDescription()
    if ([string]::IsNullOrEmpty($desc)) { throw "Description should not be empty" }
}
#endregion

#region Test 4: NavigationCommand
Test-Component "NavigationCommand creation and execution" {
    . "$PSScriptRoot\src\Core\Commands\NavigationCommand.ps1"
    . "$PSScriptRoot\src\Core\NavigationState.ps1"
    
    # Create mock repositories
    $mockRepos = @(
        [RepositoryModel]::new("Repo1", "C:\Test\Repo1"),
        [RepositoryModel]::new("Repo2", "C:\Test\Repo2")
    )
    
    # Create state
    $state = [NavigationState]::new($mockRepos)
    
    # Test Down command
    $downCmd = [NavigationCommand]::new("Down")
    if (-not $downCmd.CanExecute($state)) { throw "Should be able to execute" }
    
    $downCmd.Execute($state, @{})
    if ($state.SelectedIndex -ne 1) { throw "Should move to index 1" }
    if (-not $state.RequiresPartialRedraw) { throw "Should require partial redraw" }
    
    # Test Up command
    $state.ClearRedrawFlags()
    $upCmd = [NavigationCommand]::new("Up")
    $upCmd.Execute($state, @{})
    if ($state.SelectedIndex -ne 0) { throw "Should move back to index 0" }
    if (-not $state.RequiresPartialRedraw) { throw "Should require partial redraw" }
}
#endregion

#region Test 5: RenderOrchestrator
Test-Component "RenderOrchestrator creation" {
    . "$PSScriptRoot\src\Services\RenderOrchestrator.ps1"
    
    # Create mock dependencies
    $mockConsole = [PSCustomObject]@{
        ClearScreen = { }
        SetCursorPosition = { param($x, $y) }
    }
    
    $mockRenderer = [PSCustomObject]@{
        RenderHeader = { param($text) }
        RenderMenu = { }
        RenderRepositoryItem = { param($repo, $selected) }
        RenderGitStatusFooter = { param($repo, $total, $loaded) }
        UpdateRepositoryItemAt = { param($line, $repo, $selected) }
        ClearGitStatusFooter = { param($line) }
        RenderSuccess = { param($msg) }
        RenderWarning = { param($msg) }
        RenderError = { param($msg) }
    }
    
    # Create orchestrator
    $orchestrator = [RenderOrchestrator]::new($mockRenderer, $mockConsole)
    
    if ($null -eq $orchestrator) { throw "Failed to create RenderOrchestrator" }
    if ($null -eq $orchestrator.Renderer) { throw "Renderer not set" }
    if ($null -eq $orchestrator.Console) { throw "Console not set" }
}
#endregion

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($ErrorCount -eq 0) {
    Write-Host "All tests PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Phase 1 infrastructure is ready." -ForegroundColor Green
    Write-Host "You can now proceed to Phase 2." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "$ErrorCount test(s) FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues before proceeding." -ForegroundColor Red
    exit 1
}
    exit 1
}
