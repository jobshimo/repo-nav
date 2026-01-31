<#
.SYNOPSIS
    Tests for ConfigurationService class
    
.DESCRIPTION
    Unit tests to verify configuration loading, saving, and validation
#>

# Load dependencies
$scriptRoot = Split-Path $PSScriptRoot -Parent
. "$scriptRoot\src\Config\_index.ps1"
[Constants]::Initialize($scriptRoot)
. "$scriptRoot\src\Services\ConfigurationService.ps1"

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

function Assert-NotNull {
    param([object]$Object, [string]$TestName)
    
    if ($null -ne $Object) {
        Write-Host "    [PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "    [FAIL] $TestName (was null)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Assert-True {
    param([bool]$Condition, [string]$TestName)
    Assert-Equal $true $Condition $TestName
}

function Assert-False {
    param([bool]$Condition, [string]$TestName)
    Assert-Equal $false $Condition $TestName
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATIONSERVICE TESTS" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

#region Empty Configuration Tests
Write-Host "  Empty Configuration:" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()
$service = [ConfigurationService]::new($tempFile)

# Test non-existent file
$config = $service.LoadConfiguration()
Assert-NotNull $config "LoadConfiguration returns object for missing file"
Assert-NotNull $config.aliases "Config has aliases property"
Assert-NotNull $config.favorites "Config has favorites property"
Assert-Equal 0 $config.favorites.Count "Empty favorites array"

# Test CreateEmptyConfiguration
$emptyConfig = $service.CreateEmptyConfiguration()
Assert-NotNull $emptyConfig "CreateEmptyConfiguration works"
Assert-NotNull $emptyConfig.aliases "Empty config has aliases"
Assert-Equal 0 $emptyConfig.favorites.Count "Empty config has empty favorites"

#endregion

#region Save and Load Tests
Write-Host ""
Write-Host "  Save and Load:" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()
$service = [ConfigurationService]::new($tempFile)

# Create test configuration
$testConfig = [PSCustomObject]@{
    aliases = [PSCustomObject]@{
        'C:\Repos\Test1' = [PSCustomObject]@{
            alias = 'test1'
            color = 'Red'
        }
        'C:\Repos\Test2' = [PSCustomObject]@{
            alias = 'test2'
            color = 'Blue'
        }
    }
    favorites = @('C:\Repos\Test1', 'C:\Repos\Test3')
}

# Save
$saveResult = $service.SaveConfiguration($testConfig)
Assert-True $saveResult "SaveConfiguration succeeds"
Assert-True (Test-Path $tempFile) "Config file created"

# Load
$loadedConfig = $service.LoadConfiguration()
Assert-NotNull $loadedConfig "LoadConfiguration returns data"
Assert-NotNull $loadedConfig.aliases "Loaded config has aliases"
Assert-Equal 2 $loadedConfig.favorites.Count "Loaded favorites count correct"

# Verify aliases
$alias1 = $loadedConfig.aliases.'C:\Repos\Test1'
Assert-NotNull $alias1 "Alias 1 loaded"
Assert-Equal 'test1' $alias1.alias "Alias 1 name correct"
Assert-Equal 'Red' $alias1.color "Alias 1 color correct"

# Cleanup
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

#endregion

#region Legacy Format Migration Tests
Write-Host ""
Write-Host "  Legacy Format Migration:" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()

# Create old format (no favorites)
$oldFormat = @{
    'C:\Repos\Old1' = @{
        alias = 'old1'
        color = 'Green'
    }
} | ConvertTo-Json

$oldFormat | Set-Content $tempFile -Encoding UTF8

$service = [ConfigurationService]::new($tempFile)
$config = $service.LoadConfiguration()

Assert-NotNull $config.aliases "Old format migrated: has aliases"
Assert-NotNull $config.favorites "Old format migrated: has favorites"
Assert-Equal 0 $config.favorites.Count "Old format migrated: favorites empty"

# Cleanup
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

#endregion

#region Favorites Normalization Tests
Write-Host ""
Write-Host "  Favorites Normalization:" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()

# Test single string favorite (old bug)
$weirdFormat = @{
    aliases = @{}
    favorites = 'C:\SingleFavorite'
} | ConvertTo-Json

$weirdFormat | Set-Content $tempFile -Encoding UTF8

$service = [ConfigurationService]::new($tempFile)
$config = $service.LoadConfiguration()

Assert-True ($config.favorites -is [array]) "Single string converted to array"
Assert-Equal 1 $config.favorites.Count "Single favorite count is 1"
Assert-Equal 'C:\SingleFavorite' $config.favorites[0] "Favorite value preserved"

# Cleanup
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

#endregion

#region File Existence Tests
Write-Host ""
Write-Host "  File Existence:" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()
$service = [ConfigurationService]::new($tempFile)

Assert-True $service.ConfigurationExists() "ConfigurationExists true for existing file"

Remove-Item $tempFile -Force
Assert-False $service.ConfigurationExists() "ConfigurationExists false for missing file"

#endregion

Write-Host ""
Write-Host "================================================" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "  RESULTS: $($script:TestsPassed) passed, $($script:TestsFailed) failed" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

exit $script:TestsFailed
