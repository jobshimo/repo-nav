# tests/Pester/Unit/Services.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "Services Layer Loading" {
    BeforeAll {
        # Load all dependencies via Test-Setup
        . "$PSScriptRoot\..\..\Test-Setup.ps1"
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"

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
