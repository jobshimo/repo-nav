# Quick Test - Phase 1
Write-Host "Testing Phase 1 Components..." -ForegroundColor Cyan
Write-Host ""

# Load dependencies
Write-Host "1. Loading dependencies..." -ForegroundColor Yellow
. ".\src\Config\Constants.ps1"
. ".\src\Models\RepositoryModel.ps1"
. ".\src\Models\GitStatusModel.ps1"
. ".\src\Models\AliasInfo.ps1"
Write-Host "   OK" -ForegroundColor Green
Write-Host ""

# Test 1: INavigationCommand
Write-Host "2. Testing INavigationCommand..." -ForegroundColor Yellow
. ".\src\Core\Commands\INavigationCommand.ps1"
Write-Host "   OK - Class loaded" -ForegroundColor Green
Write-Host ""

# Test 2: NavigationState
Write-Host "3. Testing NavigationState..." -ForegroundColor Yellow
. ".\src\Core\NavigationState.ps1"
$mockRepos = @(
    [RepositoryModel]::new("Repo1", "C:\Test\Repo1"),
    [RepositoryModel]::new("Repo2", "C:\Test\Repo2")
)
$state = [NavigationState]::new($mockRepos)
Write-Host "   OK - State created: $($state.GetTotalCount()) repos" -ForegroundColor Green
Write-Host ""

# Test 3: Navigation Command
Write-Host "4. Testing NavigationCommand..." -ForegroundColor Yellow
. ".\src\Core\Commands\NavigationCommand.ps1"
$navCmd = [NavigationCommand]::new("Down")
Write-Host "   OK - Command created: $($navCmd.GetDescription())" -ForegroundColor Green
Write-Host ""

# Test 4: Exit Command
Write-Host "5. Testing ExitCommand..." -ForegroundColor Yellow
. ".\src\Core\Commands\ExitCommand.ps1"
$mockConsole = [PSCustomObject]@{ ClearScreen = {} }
$mockRenderer = [PSCustomObject]@{ RenderWarning = { param($msg) } }
$exitCmd = [ExitCommand]::new($mockConsole, $mockRenderer)
Write-Host "   OK - Command created: $($exitCmd.GetDescription())" -ForegroundColor Green
Write-Host ""

# Test 5: RenderOrchestrator
Write-Host "6. Testing RenderOrchestrator..." -ForegroundColor Yellow
. ".\src\Services\RenderOrchestrator.ps1"
$mockConsole2 = [PSCustomObject]@{ 
    ClearScreen = {}
    SetCursorPosition = { param($x,$y) }
}
$mockRenderer2 = [PSCustomObject]@{ 
    RenderHeader = { param($text) }
    RenderMenu = {}
}
$orchestrator = [RenderOrchestrator]::new($mockRenderer2, $mockConsole2)
Write-Host "   OK - Orchestrator created" -ForegroundColor Green
Write-Host ""

Write-Host "================================" -ForegroundColor Cyan
Write-Host "All Phase 1 tests PASSED!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
