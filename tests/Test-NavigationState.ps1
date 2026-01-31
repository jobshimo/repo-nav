<#
.SYNOPSIS
    Tests for NavigationState - SIMPLIFIED VERSION
    
.DESCRIPTION
    Tests core functionality with simplified assertions
#>

$scriptRoot = Split-Path $PSScriptRoot -Parent
. "$scriptRoot\src\Config\_index.ps1"
[Constants]::Initialize($scriptRoot)
. "$scriptRoot\src\Models\_index.ps1"
. "$scriptRoot\src\Services\WindowSizeCalculator.ps1"
. "$scriptRoot\src\Core\State\NavigationState.ps1"

$script:Passed = 0
$script:Failed = 0

function Pass { param([string]$n) Write-Host "    [PASS] $n" -ForegroundColor Green; $script:Passed++ }
function Fail { param([string]$n, $e, $a) Write-Host "    [FAIL] $n (Expected: $e, Got: $a)" -ForegroundColor Red; $script:Failed++ }
function Eq { param($e, $a, [string]$n) if ($e -eq $a) { Pass $n } else { Fail $n $e $a } }

Write-Host "`n====================================`n  NAVIGATIONSTATE TESTS`n====================================" -ForegroundColor Cyan

$repos = @(
    [PSCustomObject]@{ Name = "Repo1"; FullPath = "C:\R1" },
    [PSCustomObject]@{ Name = "Repo2"; FullPath = "C:\R2" },
    [PSCustomObject]@{ Name = "Repo3"; FullPath = "C:\R3" }
)

Write-Host "`n  Basic Navigation:" -ForegroundColor Yellow
$s = [NavigationState]::new($repos)
Eq 0 $s.GetCurrentIndex() "Initial index is 0"
Eq 3 $s.GetRepositories().Count "Has 3 repositories"

$s.SetCurrentIndex(1)
Eq 1 $s.GetCurrentIndex() "SetCurrentIndex works"

$s.SetCurrentIndex(999)
Eq 1 $s.GetCurrentIndex() "Invalid index ignored"

Write-Host "`n  Exit State:" -ForegroundColor Yellow
Eq "None" $s.GetExitState() "Initial exit state"
$s.SetExitState("OpenRepository")
Eq "OpenRepository" $s.GetExitState() "Exit state changed"

Write-Host "`n  Redraw Flags:" -ForegroundColor Yellow
$s.MarkForFullRedraw()
if ($s.RequiresFullRedraw) { Pass "MarkForFullRedraw" } else { Fail "MarkForFullRedraw" "True" "False" }
$s.ClearRedrawFlags()
if (-not $s.RequiresFullRedraw) { Pass "ClearRedrawFlags" } else { Fail "ClearRedrawFlags" "False" "True" }

Write-Host "`n  Repository Management:" -ForegroundColor Yellow
$newRepos = @([PSCustomObject]@{ Name = "NewRepo"; FullPath = "C:\New" })
$s.SetRepositories($newRepos)
Eq 1 $s.GetRepositories().Count "SetRepositories works"
Eq 0 $s.GetCurrentIndex() "Index reset"

Write-Host "`n  Hierarchical Navigation:" -ForegroundColor Yellow
$s2 = [NavigationState]::new($repos, "C:\Base")
Eq "C:\Base" $s2.GetCurrentPath() "BasePath set"
if (-not $s2.CanGoBack()) { Pass "Cannot go back from root" } else { Fail "Cannot go back from root" "False" "True" }

$childRepos = @([PSCustomObject]@{ Name = "Child"; FullPath = "C:\Base\Child" })
$s2.EnterContainer("C:\Base\Container", $childRepos)
Eq "C:\Base\Container" $s2.GetCurrentPath() "EnterContainer works"
if ($s2.CanGoBack()) { Pass "Can go back from subfolder" } else { Fail "Can go back from subfolder" "True" "False" }

$s2.GoBack()
Eq "C:\Base" $s2.GetCurrentPath() "GoBack works"

Write-Host "`n====================================`n  $($script:Passed) PASSED, $($script:Failed) FAILED`n====================================" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })

exit $script:Failed
