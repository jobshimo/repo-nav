
$ErrorActionPreference = "Stop"

try {
    Write-Host "Loading repo-nav environment..." -ForegroundColor Cyan
    
    # Source everything like repo-nav.ps1 does, but don't start the loop
    $scriptRoot = $PSScriptRoot
    $srcPath = Join-Path $scriptRoot "src"

    # Config
    . "$srcPath\Config\Constants.ps1"
    . "$srcPath\Config\ColorPalette.ps1"
    [Constants]::Initialize($scriptRoot)

    # Models
    . "$srcPath\Models\GitStatusModel.ps1"
    . "$srcPath\Models\AliasInfo.ps1"
    . "$srcPath\Models\RepositoryModel.ps1"

    # Services
    . "$srcPath\Services\WindowSizeCalculator.ps1"
    . "$srcPath\Core\NavigationState.ps1"
    . "$srcPath\Services\ConfigurationService.ps1"
    . "$srcPath\Services\UserPreferencesService.ps1"
    . "$srcPath\Services\LocalizationService.ps1"
    . "$srcPath\Services\AliasManager.ps1"
    . "$srcPath\Services\GitService.ps1"
    . "$srcPath\Services\NpmService.ps1"
    . "$srcPath\Services\ParallelGitLoader.ps1"
    . "$srcPath\Services\RepositoryOperationsService.ps1"
    . "$srcPath\Services\FavoriteService.ps1"
    . "$srcPath\Services\SearchService.ps1"
    . "$srcPath\Services\RenderOrchestrator.ps1"

    # UI
    . "$srcPath\UI\ConsoleHelper.ps1"
    . "$srcPath\UI\ProgressIndicator.ps1"
    . "$srcPath\UI\UIRenderer.ps1"
    . "$srcPath\UI\ColorSelector.ps1"
    . "$srcPath\UI\OptionSelector.ps1"
    . "$srcPath\UI\FilteredListSelector.ps1"  # <--- NEW FILE

    # Managers
    . "$srcPath\Core\RepositoryManager.ps1"

    # Views
    . "$srcPath\UI\Views\RepositoryManagementView.ps1"
    . "$srcPath\UI\Views\AliasView.ps1"
    . "$srcPath\UI\Views\SearchView.ps1"

    # Context
    . "$srcPath\Core\CommandContext.ps1"

    # Commands
    . "$srcPath\Core\Commands\INavigationCommand.ps1"
    # Load all commands
    Get-ChildItem "$srcPath\Core\Commands\*.ps1" | ForEach-Object { . $_.FullName }

    # Core
    . "$srcPath\Core\CommandFactory.ps1"
    . "$srcPath\Core\InputHandler.ps1"

    Write-Host "Environment loaded." -ForegroundColor Green
    
    Write-Host "Initializing CommandFactory..." -ForegroundColor Cyan
    $factory = [CommandFactory]::new()
    $commands = $factory.GetCommands()
    
    Write-Host "Registered Commands:" -ForegroundColor Yellow
    foreach ($cmd in $commands) {
        $desc = $cmd.GetDescription()
        Write-Host " - $($cmd.GetType().Name): $desc"
        
        if ($cmd.GetType().Name -eq "GitFlowCommand") {
             Write-Host "   SUCCESS: GitFlowCommand is registered!" -ForegroundColor Green
        }
    }
    
    $gitFlowFound = $commands | Where-Object { $_.GetType().Name -eq "GitFlowCommand" }
    
    if (-not $gitFlowFound) {
        Write-Host "ERROR: GitFlowCommand is NOT registered!" -ForegroundColor Red
        
        # Try to instantiate manually to see if class exists
        try {
            $test = [GitFlowCommand]::new()
            Write-Host "   Class [GitFlowCommand] exists and can be instantiated manually." -ForegroundColor Yellow
        }
        catch {
             Write-Host "   Class [GitFlowCommand] CANNOT be instantiated: $_" -ForegroundColor Red
        }
    }

} catch {
    Write-Error "Error: $_"
    Write-Host "StackTrace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
