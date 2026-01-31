# tests/Pester/Unit/Services.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "Services Layer Loading" {
    BeforeAll {
        # Load dependencies (Layers 1, 2, 3)
        # We access them via relative path from the test file or using the helper
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        
        # Layer 1: Config
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize("$srcRoot\..")

        # Layer 2: Models
        . "$srcRoot\Models\_index.ps1"

        # Layer 3: Core Infrastructure
        . "$srcRoot\Core\Interfaces\IProgressReporter.ps1"
        . "$srcRoot\Services\WindowSizeCalculator.ps1"
        . "$srcRoot\Core\State\NavigationState.ps1"
        # Skip Startup/ServiceRegistry for now if not needed, or mock it? 
        # Services often don't depend on ServiceRegistry for *definition*, only for *usage*.
        # But some might uses static [ServiceRegistry]::Resolve inside methods.
        # Let's load ServiceRegistry just in case, though it resets state.
        . "$srcRoot\Startup\ServiceRegistry.ps1"

        # Load Services Layer (Subject Under Test)
        # We load it here to expose types to all tests.
        . "$srcRoot\Services\_index.ps1"
    }

    Context "Dependency Ordering" {
        It "Services Types are available" {
           [GitService] | Should -Not -BeNullOrEmpty
        }
    }

    Context "GitService Instantiation" {
        It "Can be instantiated" {
            $service = [GitService]::new()
            $service | Should -Not -BeNullOrEmpty
        }
    }

    Context "GitReadService Instantiation" {
        It "Can be instantiated" {
            [GitReadService]::new() | Should -Not -BeNullOrEmpty
        }
    }

    Context "GitWriteService Instantiation" {
        It "Can be instantiated" {
            [GitWriteService]::new() | Should -Not -BeNullOrEmpty
        }
    }

    Context "ConfigurationService Instantiation" {
        It "Can be instantiated" {
            [ConfigurationService]::new() | Should -Not -BeNullOrEmpty
        }
    }

    Context "UserPreferencesService Instantiation" {
        It "Can be instantiated" {
            [UserPreferencesService]::new() | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "NpmService Instantiation" {
        It "Can be instantiated" {
            [NpmService]::new() | Should -Not -BeNullOrEmpty
        }
    }
}
