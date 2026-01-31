# tests/Pester/Unit/ArrayHelper.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "ArrayHelper" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Services\ArrayHelper.ps1"
    }

    Context "EnsureArray" {
        It "Null returns empty array" {
            $res = [ArrayHelper]::EnsureArray($null)
            , $res | Should -BeOfType [System.Array]
            $res.Count | Should -Be 0
        }

        It "Single string returns array with one element" {
            $res = [ArrayHelper]::EnsureArray("String")
            $res.Count | Should -Be 1
            $res[0] | Should -Be "String"
        }

        It "Filters nulls and empty strings" {
            $arr = @("A", $null, "B", "  ", "")
            $res = [ArrayHelper]::EnsureArray($arr)
            $res.Count | Should -Be 2
            $res -contains "A" | Should -BeTrue
            $res -contains "B" | Should -BeTrue
        }

        It "Generic object returns single-element array" {
            $obj = @{ Prop = "Value" }
            $res = [ArrayHelper]::EnsureArray($obj)
            $res.Count | Should -Be 1
            $res[0].Prop | Should -Be "Value"
        }
        
        It "Whitespace string returns empty array" {
            $res = [ArrayHelper]::EnsureArray("   ")
            $res.Count | Should -Be 0
        }
    }

    Context "AddToArray" {
        It "Adds to null creates array" {
            $res = [ArrayHelper]::AddToArray($null, "New")
            $res.Count | Should -Be 1
            $res[0] | Should -Be "New"
        }

        It "Adds to single string" {
            $res = [ArrayHelper]::AddToArray("Old", "New")
            $res.Count | Should -Be 2
            $res[1] | Should -Be "New"
        }

        It "Does not add null or whitespace items" {
            $res = [ArrayHelper]::AddToArray(@("A"), $null)
            $res.Count | Should -Be 1
            
            $res = [ArrayHelper]::AddToArray(@("A"), "  ")
            $res.Count | Should -Be 1
        }
    }

    Context "RemoveFromArray" {
        It "Removes existing element" {
            $arr = @("A", "B", "C")
            $res = [ArrayHelper]::RemoveFromArray($arr, "B")
            $res.Count | Should -Be 2
            $res -contains "B" | Should -BeFalse
        }

        It "Handles removing item that doesn't exist" {
            $arr = @("A", "B")
            $res = [ArrayHelper]::RemoveFromArray($arr, "Z")
            $res.Count | Should -Be 2
        }
    }

    Context "Contains" {
        It "Returns true if item exists (case-insensitive)" {
            $arr = @("Apple", "Banana")
            [ArrayHelper]::Contains($arr, "apple") | Should -BeTrue
        }

        It "Returns false if item missing" {
            $arr = @("Apple", "Banana")
            [ArrayHelper]::Contains($arr, "Cherry") | Should -BeFalse
        }
        
        It "Handles null input gracefully" {
            [ArrayHelper]::Contains($null, "Anything") | Should -BeFalse
        }
    }
}
