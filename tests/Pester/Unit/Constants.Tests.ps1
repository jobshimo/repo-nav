Describe "Constants" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Capture original root to restore later
        $originalRoot = [Constants]::ScriptRoot
    }

    AfterAll {
        # Restore original root
        [Constants]::Initialize($originalRoot)
    }

    Context "Initialization" {
        It "Sets ScriptRoot correctly" {
            $testRoot = "C:\Test\Root"
            [Constants]::Initialize($testRoot)
            [Constants]::ScriptRoot | Should -Be $testRoot
        }

        It "GetAliasFilePath combines ScriptRoot and AliasFileName" {
            $testRoot = "C:\Test\Root"
            [Constants]::Initialize($testRoot)
            
            $expected = Join-Path $testRoot ([Constants]::AliasFileName)
            [Constants]::GetAliasFilePath() | Should -Be $expected
        }
    }

    Context "Color Logic" {
        It "Returns White for DarkGreen background" {
            [Constants]::GetTextColorForBackground('DarkGreen') | Should -Be 'White'
        }

        It "Returns White for DarkRed background" {
            [Constants]::GetTextColorForBackground('DarkRed') | Should -Be 'White'
        }
        
        It "Returns Black for DarkYellow background" {
            [Constants]::GetTextColorForBackground('DarkYellow') | Should -Be 'Black'
        }

        It "Returns White for DarkMagenta background" {
            [Constants]::GetTextColorForBackground('DarkMagenta') | Should -Be 'White'
        }
        
        It "Returns White for DarkCyan background" {
            [Constants]::GetTextColorForBackground('DarkCyan') | Should -Be 'White'
        }

        It "Returns White for DarkBlue background" {
            [Constants]::GetTextColorForBackground('DarkBlue') | Should -Be 'White'
        }
        
        It "Returns Black for DarkGray background" {
             [Constants]::GetTextColorForBackground('DarkGray') | Should -Be 'Black'
        }

        It "Returns Green for Black background" {
            [Constants]::GetTextColorForBackground('Black') | Should -Be 'Green'
        }
        
        It "Returns Green for None/Empty background" {
            [Constants]::GetTextColorForBackground('None') | Should -Be 'Green'
            [Constants]::GetTextColorForBackground($null) | Should -Be 'Green'
        }
    }

    Context "Key Codes" {
        # Sample check to ensure constants are loaded and have values
        It "Defines standard key codes" {
            [Constants]::KEY_Q | Should -Be 81
            [Constants]::KEY_ESC | Should -Be 27
            [Constants]::KEY_ENTER | Should -Be 13
        }
    }
    
    Context "Static Definitions" {
        It "Initializes AvailableBackgroundColors" {
            [Constants]::AvailableBackgroundColors.Count | Should -BeGreaterThan 0
            [Constants]::AvailableBackgroundColors | Should -Contain "Black"
        }
        
        It "Initializes AvailableDelimiters" {
            [Constants]::AvailableDelimiters.Count | Should -BeGreaterThan 0
            $arrow = [Constants]::AvailableDelimiters | Where-Object Name -eq 'Arrows'
            $arrow.Left | Should -Be '< '
        }
    }
}
