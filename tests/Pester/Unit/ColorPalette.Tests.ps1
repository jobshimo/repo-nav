Describe "ColorPalette" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\ColorPalette.ps1"
    }

    Context "Validation" {
        It "IsValidColor returns true for known colors" {
            [ColorPalette]::IsValidColor("Cyan") | Should -BeTrue
            [ColorPalette]::IsValidColor("Red") | Should -BeTrue
        }

        It "IsValidColor returns false for unknown colors" {
            [ColorPalette]::IsValidColor("NotAColor") | Should -BeFalse
            [ColorPalette]::IsValidColor($null) | Should -BeFalse
        }
    }

    Context "Defaults" {
        It "GetColorOrDefault returns input if valid" {
            [ColorPalette]::GetColorOrDefault("Green") | Should -Be "Green"
        }

        It "GetColorOrDefault returns default if invalid" {
            $default = [ColorPalette]::DefaultAliasColor
            [ColorPalette]::GetColorOrDefault("InvalidColor") | Should -Be $default
        }
        
        It "GetColorOrDefault returns default if null" {
             $default = [ColorPalette]::DefaultAliasColor
            [ColorPalette]::GetColorOrDefault($null) | Should -Be $default
        }
    }
}
