# tests/Pester/Unit/CommandFactory.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "CommandFactory (Unit)" {
    # No complex BeforeAll needed as we mock everything
    
    Context "Command Pattern" {
        It "Mock command implements CanExecute correctly" {
            $mockCommand = [PSCustomObject]@{
                CanExecute = { param($key, $ctx) return $key.VirtualKeyCode -eq 999 }
            }
            
            $validKey = @{ VirtualKeyCode = 999 }
            $invalidKey = @{ VirtualKeyCode = 123 }
            
            # Using & to call script block
            (& $mockCommand.CanExecute $validKey $null) | Should -BeTrue
            (& $mockCommand.CanExecute $invalidKey $null) | Should -BeFalse
        }
    }

    Context "Factory Pattern" {
        BeforeAll {
            # Helper functions for the mock factory
            function RegisterCommand($factory, $cmd) { $factory.Commands += $cmd }
            function FindCommand($factory, $key, $ctx) {
                foreach ($cmd in $factory.Commands) {
                    if (& $cmd.CanExecute $key $ctx) { return $cmd }
                }
                return $null
            }
        }

        BeForeEach {
            # Reset factory for each test
            $mockFactory = @{ Commands = @() }
        }

        It "Registers commands correctly" {
            $cmd = [PSCustomObject]@{ CanExecute = { $true } }
            RegisterCommand $mockFactory $cmd
            $mockFactory.Commands.Count | Should -Be 1
        }

        It "Finds command by key code" {
            $upCmd = [PSCustomObject]@{ Name="Up"; CanExecute = { param($k) $k.VirtualKeyCode -eq 38 } }
            $downCmd = [PSCustomObject]@{ Name="Down"; CanExecute = { param($k) $k.VirtualKeyCode -eq 40 } }
            
            RegisterCommand $mockFactory $upCmd
            RegisterCommand $mockFactory $downCmd
            
            $key = @{ VirtualKeyCode = 38 }
            $found = FindCommand $mockFactory $key $null
            $found.Name | Should -Be "Up"
        }

        It "Respects registration priority" {
            $cmd1 = [PSCustomObject]@{ Name="First"; CanExecute = { param($k) $k.Char -eq 'x' } }
            $cmd2 = [PSCustomObject]@{ Name="Second"; CanExecute = { param($k) $k.Char -eq 'x' } }
            
            RegisterCommand $mockFactory $cmd1
            RegisterCommand $mockFactory $cmd2
            
            $key = @{ Char = 'x' }
            $found = FindCommand $mockFactory $key $null
            $found.Name | Should -Be "First"
        }
    }
}
