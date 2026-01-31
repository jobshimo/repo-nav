# tests/Pester/Unit/NavigationState.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "NavigationState" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize("$srcRoot\..")
        . "$srcRoot\Models\_index.ps1"
        . "$srcRoot\Services\WindowSizeCalculator.ps1"
        # Load ArrayHelper for NavigationState
        . "$srcRoot\Services\ArrayHelper.ps1"
        . "$srcRoot\Core\State\NavigationState.ps1"
        
        $repos = @(
            [PSCustomObject]@{ Name = "Repo1"; FullPath = "C:\R1" },
            [PSCustomObject]@{ Name = "Repo2"; FullPath = "C:\R2" }
        )
    }

    Context "Basic Navigation" {
        It "New instance starts at index 0" {
            $s = [NavigationState]::new($repos)
            $s.GetCurrentIndex() | Should -Be 0
        }

        It "SetCurrentIndex updates index" {
            $s = [NavigationState]::new($repos)
            $s.SetCurrentIndex(1)
            $s.GetCurrentIndex() | Should -Be 1
        }

        It "Invalid index is ignored" {
            $s = [NavigationState]::new($repos)
            $s.SetCurrentIndex(99)
            $s.GetCurrentIndex() | Should -Be 0
        }
    }

    Context "Redraw Flags" {
        It "MarkForFullRedraw sets flag" {
            $s = [NavigationState]::new($repos)
            $s.MarkForFullRedraw()
            $s.RequiresFullRedraw | Should -BeTrue
        }
    }
}
