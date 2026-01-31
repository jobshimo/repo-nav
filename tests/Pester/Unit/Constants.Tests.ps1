Describe "Constants" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\Constants.ps1"
    }

    Context "Initialization" {
        It "Initialize sets ScriptRoot" {
            $path = "C:\Test\Root"
            [Constants]::Initialize($path)
            [Constants]::ScriptRoot | Should -Be $path
        }
    }
    
    Context "Colors" {
        It "GetTextColorForBackground returns correct contrast" {
            [Constants]::GetTextColorForBackground("DarkGreen") | Should -Be "White"
            [Constants]::GetTextColorForBackground("Black") | Should -Be "Green"
        }
    }
}
