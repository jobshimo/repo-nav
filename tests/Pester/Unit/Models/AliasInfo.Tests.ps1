# tests/Pester/Unit/Models/AliasInfo.Tests.ps1

Describe "AliasInfo" {
    BeforeAll {
        $scriptRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        . "$scriptRoot/Test-Setup.ps1"
    }

    Context "Constructor with color" {
        It "Creates alias with valid color" {
            $alias = [AliasInfo]::new("myalias", "Cyan")
            $alias.Alias | Should -Be "myalias"
            $alias.Color | Should -Be "Cyan"
        }

        It "Uses default color for invalid color" {
            $alias = [AliasInfo]::new("test", "InvalidColor")
            $alias.Alias | Should -Be "test"
            $alias.Color | Should -Be ([ColorPalette]::DefaultAliasColor)
        }

        It "Handles empty color string" {
            $alias = [AliasInfo]::new("test", "")
            $alias.Color | Should -Be ([ColorPalette]::DefaultAliasColor)
        }

        It "Handles null color" {
            $alias = [AliasInfo]::new("test", $null)
            $alias.Color | Should -Be ([ColorPalette]::DefaultAliasColor)
        }
    }

    Context "Constructor without color" {
        It "Creates alias with default color" {
            $alias = [AliasInfo]::new("myalias")
            $alias.Alias | Should -Be "myalias"
            $alias.Color | Should -Be ([ColorPalette]::DefaultAliasColor)
        }
    }

    Context "IsValid" {
        It "Returns true for valid alias" {
            $alias = [AliasInfo]::new("validalias")
            $alias.IsValid() | Should -BeTrue
        }

        It "Returns false for alias with spaces" {
            $alias = [AliasInfo]::new("invalid alias")
            $alias.IsValid() | Should -BeFalse
        }

        It "Returns false for empty alias" {
            $alias = [AliasInfo]::new("")
            $alias.IsValid() | Should -BeFalse
        }

        It "Returns false for whitespace-only alias" {
            $alias = [AliasInfo]::new("   ")
            $alias.IsValid() | Should -BeFalse
        }

        It "Returns false for null alias" {
            $alias = [AliasInfo]::new($null)
            $alias.IsValid() | Should -BeFalse
        }

        It "Returns true for alias with hyphens" {
            $alias = [AliasInfo]::new("my-alias")
            $alias.IsValid() | Should -BeTrue
        }

        It "Returns true for alias with underscores" {
            $alias = [AliasInfo]::new("my_alias")
            $alias.IsValid() | Should -BeTrue
        }
    }

    Context "ToString" {
        It "Returns formatted string with alias and color" {
            $alias = [AliasInfo]::new("myalias", "Cyan")
            $result = $alias.ToString()
            $result | Should -Be "myalias [Cyan]"
        }

        It "Handles empty alias in ToString" {
            $alias = [AliasInfo]::new("")
            $result = $alias.ToString()
            $result | Should -Match "\[.*\]"
        }
    }
}
