<#
.SYNOPSIS
    Tests for ArrayHelper class.
    
.DESCRIPTION
    Unit tests to verify ArrayHelper handles PowerShell array quirks correctly.
#>

# Load dependencies
$scriptRoot = Split-Path $PSScriptRoot -Parent
. "$scriptRoot\src\Services\ArrayHelper.ps1"

$script:TestsPassed = 0
$script:TestsFailed = 0

function Assert-Equal {
    param([object]$Expected, [object]$Actual, [string]$TestName)
    
    $expectedStr = if ($null -eq $Expected) { "null" } else { $Expected.ToString() }
    $actualStr = if ($null -eq $Actual) { "null" } else { $Actual.ToString() }
    
    if ($Expected -eq $Actual) {
        Write-Host "    [PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "    [FAIL] $TestName" -ForegroundColor Red
        Write-Host "           Expected: $expectedStr" -ForegroundColor DarkRed
        Write-Host "           Actual:   $actualStr" -ForegroundColor DarkRed
        $script:TestsFailed++
    }
}

function Assert-ArrayEqual {
    param([array]$Expected, [array]$Actual, [string]$TestName)
    
    $expectedStr = "[" + ($Expected -join ", ") + "]"
    $actualStr = "[" + ($Actual -join ", ") + "]"
    
    $equal = $true
    if ($Expected.Count -ne $Actual.Count) {
        $equal = $false
    } else {
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if ($Expected[$i] -ne $Actual[$i]) {
                $equal = $false
                break
            }
        }
    }
    
    if ($equal) {
        Write-Host "    [PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "    [FAIL] $TestName" -ForegroundColor Red
        Write-Host "           Expected: $expectedStr" -ForegroundColor DarkRed
        Write-Host "           Actual:   $actualStr" -ForegroundColor DarkRed
        $script:TestsFailed++
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  ARRAYHELPER TESTS" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

#region EnsureArray Tests
Write-Host "  EnsureArray:" -ForegroundColor Yellow

# Test null
$result = [ArrayHelper]::EnsureArray($null)
Assert-ArrayEqual @() $result "Null returns empty array"

# Test empty string
$result = [ArrayHelper]::EnsureArray("")
Assert-ArrayEqual @() $result "Empty string returns empty array"

# Test single string
$result = [ArrayHelper]::EnsureArray("C:\path")
Assert-ArrayEqual @("C:\path") $result "Single string returns array with one element"

# Test array with one element
$result = [ArrayHelper]::EnsureArray(@("C:\path"))
Assert-ArrayEqual @("C:\path") $result "Array with one element preserved"

# Test array with multiple elements
$result = [ArrayHelper]::EnsureArray(@("C:\path1", "C:\path2"))
Assert-ArrayEqual @("C:\path1", "C:\path2") $result "Array with multiple elements preserved"

# Test array with nulls
$result = [ArrayHelper]::EnsureArray(@("C:\path1", $null, "", "C:\path2"))
Assert-ArrayEqual @("C:\path1", "C:\path2") $result "Filters null and empty from array"

#endregion

#region AddToArray Tests
Write-Host ""
Write-Host "  AddToArray:" -ForegroundColor Yellow

# Test add to empty
$result = [ArrayHelper]::AddToArray($null, "C:\new")
Assert-ArrayEqual @("C:\new") $result "Add to null creates array"

# Test add to single string (the problematic case!)
$result = [ArrayHelper]::AddToArray("C:\path1", "C:\path2")
Assert-ArrayEqual @("C:\path1", "C:\path2") $result "Add to single string creates array (NOT string concat)"

# Test add to array
$result = [ArrayHelper]::AddToArray(@("C:\path1", "C:\path2"), "C:\path3")
Assert-ArrayEqual @("C:\path1", "C:\path2", "C:\path3") $result "Add to array appends element"

# Test add null
$result = [ArrayHelper]::AddToArray(@("C:\path1"), $null)
Assert-ArrayEqual @("C:\path1") $result "Add null doesn't add anything"

#endregion

#region RemoveFromArray Tests
Write-Host ""
Write-Host "  RemoveFromArray:" -ForegroundColor Yellow

# Test remove from array
$result = [ArrayHelper]::RemoveFromArray(@("C:\path1", "C:\path2", "C:\path3"), "C:\path2")
Assert-ArrayEqual @("C:\path1", "C:\path3") $result "Remove from array works"

# Test remove non-existent
$result = [ArrayHelper]::RemoveFromArray(@("C:\path1"), "C:\path2")
Assert-ArrayEqual @("C:\path1") $result "Remove non-existent returns unchanged"

# Test remove from single string
$result = [ArrayHelper]::RemoveFromArray("C:\path1", "C:\path1")
Assert-ArrayEqual @() $result "Remove from single string returns empty array"

#endregion

#region Contains Tests
Write-Host ""
Write-Host "  Contains:" -ForegroundColor Yellow

# Test contains true
$result = [ArrayHelper]::Contains(@("C:\path1", "C:\path2"), "C:\path1")
Assert-Equal $true $result "Contains returns true when found"

# Test contains false
$result = [ArrayHelper]::Contains(@("C:\path1", "C:\path2"), "C:\path3")
Assert-Equal $false $result "Contains returns false when not found"

# Test contains on single string
$result = [ArrayHelper]::Contains("C:\path1", "C:\path1")
Assert-Equal $true $result "Contains works on single string"

#endregion

#region Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "  Passed: $($script:TestsPassed)  Failed: $($script:TestsFailed)" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

exit $script:TestsFailed
#endregion
