# tests/Pester/Integration/SystemLoad.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "System Integration Loading" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        # Load Startup Layer which loads everything else via indices
        # We need to load repo-nav.ps1 dependencies manually or just load AppBuilder related files?
        # AppBuilder is in src/App/AppBuilder.ps1
        # But it requires ALL indices to be loaded.
        
        # Simulating repo-nav.ps1 loading process but without execution
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize("$srcRoot\..")
        . "$srcRoot\Models\_index.ps1"
        . "$srcRoot\Core\Interfaces\IProgressReporter.ps1"
        . "$srcRoot\Services\WindowSizeCalculator.ps1"
        . "$srcRoot\Core\State\NavigationState.ps1"
        . "$srcRoot\Startup\ServiceRegistry.ps1"
        . "$srcRoot\Services\_index.ps1"
        . "$srcRoot\UI\_index.ps1"
        . "$srcRoot\Core\Services\GitStatusManager.ps1"
        . "$srcRoot\Core\Services\RepositorySorter.ps1"
        . "$srcRoot\Core\Services\OnboardingService.ps1"
        . "$srcRoot\Core\Services\PathManager.ps1"
        . "$srcRoot\Core\RepositoryManager.ps1"
        # UI Controllers... skip for AppBuilder backend context?
        # AppBuilder uses UIRenderer, etc.
        . "$srcRoot\UI\Controllers\PreferencesActionDispatcher.ps1"
        . "$srcRoot\UI\Controllers\PreferencesMenuRenderer.ps1"
        . "$srcRoot\UI\Controllers\PreferencesMenuController.ps1"
        . "$srcRoot\UI\Views\RepositoryManagementView.ps1"
        . "$srcRoot\UI\Views\AliasView.ps1"
        . "$srcRoot\UI\Views\SearchView.ps1"
        
        . "$srcRoot\Core\State\ApplicationContext.ps1"
        
        # Load AppBuilder
        . "$srcRoot\App\AppBuilder.ps1"
    }

    Context "AppBuilder Construction" {
        It "Builds Application Context successfully" {
            $mockPath = "C:\Test\Repo"
            # Mock Test-Path for the base path if AppBuilder checks it?
            # AppBuilder calls ServiceRegistry::Reset()
            
            # We assume user preferences might exist or not.
            # AppBuilder internal Build:
            # 1. Config Service
            # ...
            # 7. Compose Context
            
            $context = [AppBuilder]::Build($mockPath)
            $context | Should -Not -BeNullOrEmpty
            $context.RepoManager | Should -Not -BeNullOrEmpty
            $context.GitService | Should -BeNullOrEmpty # Context doesn't expose GitService directly, it's in Registry
            
            $gitService = [ServiceRegistry]::Resolve('GitService')
            $gitService | Should -Not -BeNullOrEmpty
        }
    }
}
