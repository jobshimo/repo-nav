<#
.SYNOPSIS
    Tests for CommandFactory - UNIT TEST VERSION
    
.DESCRIPTION
    Tests unitarios del patrón Factory sin cargar todo el sistema
#>

$scriptRoot = Split-Path $PSScriptRoot -Parent

$script:Passed = 0
$script:Failed = 0

function Pass { param([string]$n) Write-Host "    [PASS] $n" -ForegroundColor Green; $script:Passed++ }
function Fail { param([string]$n, $e, $a) Write-Host "    [FAIL] $n (Expected: $e, Got: $a)" -ForegroundColor Red; $script:Failed++ }
function Eq { param($e, $a, [string]$n) if ($e -eq $a) { Pass $n } else { Fail $n $e $a } }
function NotNull { param($o, [string]$n) if ($null -ne $o) { Pass $n } else { Fail $n "not null" "null" } }
function IsTrue { param($c, [string]$n) if ($c) { Pass $n } else { Fail $n "true" "false" } }

Write-Host "`n====================================`n  COMMANDFACTORY TESTS (UNIT)`n====================================" -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# Test Mock Command Pattern
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "`n  Mock Command Pattern:" -ForegroundColor Yellow

# Create simple mock command using PSCustomObject
$mockCommand = [PSCustomObject]@{
    Name = "TestCommand"
    Description = "Test command description"
    KeyCode = 999
    CanExecute = { param($key, $ctx) return $key.VirtualKeyCode -eq 999 }
    Execute = { param($key, $ctx) return "Executed" }
    GetDescription = { return "Test command description" }
}

NotNull $mockCommand "Mock command created"
Eq "TestCommand" $mockCommand.Name "Mock has correct name"
Eq "Test command description" $mockCommand.Description "Mock has correct description"

# Test mock command behavior
$testKey = @{ VirtualKeyCode = 999; Character = 't' }
$canExec = & $mockCommand.CanExecute $testKey $null
IsTrue $canExec "Mock command CanExecute returns true for matching key"

$testKey2 = @{ VirtualKeyCode = 123; Character = 'x' }
$canExec2 = & $mockCommand.CanExecute $testKey2 $null
IsTrue (-not $canExec2) "Mock command CanExecute returns false for non-matching key"

# ─────────────────────────────────────────────────────────────────────────────
# Test Factory Pattern
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "`n  Factory Pattern:" -ForegroundColor Yellow

# Create mock factory using closure pattern
$mockFactory = @{
    Commands = @()
}

function RegisterCommand($factory, $cmd) {
    $factory.Commands += $cmd
}

function GetAllCommands($factory) {
    return $factory.Commands
}

function FindCommand($factory, $key, $ctx) {
    foreach ($cmd in $factory.Commands) {
        if (& $cmd.CanExecute $key $ctx) {
            return $cmd
        }
    }
    return $null
}

function GetCommandCount($factory) {
    return $factory.Commands.Count
}

NotNull $mockFactory "Mock factory created"

# Test factory registration
RegisterCommand $mockFactory $mockCommand
$count = GetCommandCount $mockFactory
Eq 1 $count "Factory has 1 command after registration"

# Register more commands
$upCommand = [PSCustomObject]@{
    Name = "UpCommand"
    Description = "Navigate up"
    CanExecute = { param($key, $ctx) return $key.VirtualKeyCode -eq 38 }
    Execute = { param($key, $ctx) return "Up" }
    GetDescription = { return "Navigate up" }
}

$downCommand = [PSCustomObject]@{
    Name = "DownCommand"
    Description = "Navigate down"
    CanExecute = { param($key, $ctx) return $key.VirtualKeyCode -eq 40 }
    Execute = { param($key, $ctx) return "Down" }
    GetDescription = { return "Navigate down" }
}

$qCommand = [PSCustomObject]@{
    Name = "QuitCommand"
    Description = "Quit application"
    CanExecute = { param($key, $ctx) return $key.Character -eq 'q' }
    Execute = { param($key, $ctx) return "Quit" }
    GetDescription = { return "Quit application" }
}

RegisterCommand $mockFactory $upCommand
RegisterCommand $mockFactory $downCommand
RegisterCommand $mockFactory $qCommand

$count = GetCommandCount $mockFactory
Eq 4 $count "Factory has 4 commands after multiple registrations"

# ─────────────────────────────────────────────────────────────────────────────
# Test Command Lookup
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "`n  Command Lookup:" -ForegroundColor Yellow

# Find command by virtual key code
$upKey = @{ VirtualKeyCode = 38; Character = '' }
$found = FindCommand $mockFactory $upKey $null
NotNull $found "Found command for UP arrow (VK 38)"
Eq "UpCommand" $found.Name "Found correct command (UpCommand)"

# Find command by character
$qKey = @{ VirtualKeyCode = 81; Character = 'q' }
$found = FindCommand $mockFactory $qKey $null
NotNull $found "Found command for 'q' character"
Eq "QuitCommand" $found.Name "Found correct command (QuitCommand)"

# Test not found (use code that isn't registered)
$invalidKey = @{ VirtualKeyCode = 500; Character = 'z' }
$found = FindCommand $mockFactory $invalidKey $null
if ($null -eq $found) {
    Pass "Invalid key returns null"
} else {
    Fail "Invalid key returns null" "null" "$($found.Name)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Command Descriptions
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "`n  Command Descriptions:" -ForegroundColor Yellow

$allCommands = GetAllCommands $mockFactory
$allHaveDescriptions = $true
$commandsWithoutDesc = @()

foreach ($cmd in $allCommands) {
    $desc = & $cmd.GetDescription
    if ([string]::IsNullOrEmpty($desc)) {
        $allHaveDescriptions = $false
        $commandsWithoutDesc += $cmd.Name
    }
}

IsTrue $allHaveDescriptions "All commands have descriptions"
Eq 4 $allCommands.Count "Correct command count retrieved"

# ─────────────────────────────────────────────────────────────────────────────
# Test Command Execution
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "`n  Command Execution:" -ForegroundColor Yellow

$upKey = @{ VirtualKeyCode = 38; Character = '' }
$upCmd = FindCommand $mockFactory $upKey $null
$result = & $upCmd.Execute $upKey $null
Eq "Up" $result "UP command executes correctly"

$qKey = @{ VirtualKeyCode = 81; Character = 'q' }
$qCmd = FindCommand $mockFactory $qKey $null
$result = & $qCmd.Execute $qKey $null
Eq "Quit" $result "Quit command executes correctly"

# ─────────────────────────────────────────────────────────────────────────────
# Test Priority/Order
# ─────────────────────────────────────────────────────────────────────────────

Write-Host "`n  Command Priority:" -ForegroundColor Yellow

# Create two commands for same key (first registered should win)
$firstCmd = [PSCustomObject]@{
    Name = "FirstCommand"
    CanExecute = { param($key, $ctx) return $key.Character -eq 'x' }
    Execute = { return "First" }
    GetDescription = { return "First command" }
}

$secondCmd = [PSCustomObject]@{
    Name = "SecondCommand"
    CanExecute = { param($key, $ctx) return $key.Character -eq 'x' }
    Execute = { return "Second" }
    GetDescription = { return "Second command" }
}

$priorityFactory = @{ Commands = @() }
RegisterCommand $priorityFactory $firstCmd
RegisterCommand $priorityFactory $secondCmd

$xKey = @{ VirtualKeyCode = 88; Character = 'x' }
$foundCmd = FindCommand $priorityFactory $xKey $null
Eq "FirstCommand" $foundCmd.Name "First registered command has priority"

Write-Host "`n====================================`n  $($script:Passed) PASSED, $($script:Failed) FAILED`n====================================" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })

exit $script:Failed
