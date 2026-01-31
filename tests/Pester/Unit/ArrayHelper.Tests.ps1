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

        It "Filters nulls" {
            $arr = @("A", $null, "B")
            $res = [ArrayHelper]::EnsureArray($arr)
            $res.Count | Should -Be 2
        }
    }

    Context "AddToArray" {
        It "Adds to null creates array" {
            $res = [ArrayHelper]::AddToArray($null, "New")
            $res.Count | Should -Be 1
        }

        It "Adds to single string" {
            $res = [ArrayHelper]::AddToArray("Old", "New")
            $res.Count | Should -Be 2
            $res[1] | Should -Be "New"
        }
    }

    Context "RemoveFromArray" {
        It "Removes existing element" {
            $arr = @("A", "B", "C")
            $res = [ArrayHelper]::RemoveFromArray($arr, "B")
            $res.Count | Should -Be 2
            $res -contains "B" | Should -BeFalse
        }
    }
}
