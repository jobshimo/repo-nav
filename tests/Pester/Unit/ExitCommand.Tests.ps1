Describe "ExitCommand" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load the class (if not loaded by Test-Setup, but it is in commands layer)
        # Test-Setup loads commands layer 5? No, line 66 says Layer 5 is Commands.
        # Wait, repo-nav.ps1 says Layer 5 is Commands. Test-Setup.ps1 says Layer 8 is Command System.
        # Let's rely on Test-Setup.
    }

    BeforeEach {
        $command = [ExitCommand]::new()
        $context = [CommandContext]::new()
        $state = [NavigationState]::new(@()) # Empty repos
        $context.State = $state
    }

    Context "Metadata" {
        It "Returns correct description" {
            $command.GetDescription() | Should -Be "Exit navigation (Q/ESC)"
        }
    }

    Context "CanExecute" {
        It "Returns true for Q key" {
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_Q }
            $command.CanExecute($keyPress, $context) | Should -Be $true
        }

        It "Returns true for ESC key" {
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_ESC }
            $command.CanExecute($keyPress, $context) | Should -Be $true
        }

        It "Returns false for other keys" {
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = 65 } # A
            $command.CanExecute($keyPress, $context) | Should -Be $false
        }
    }

    Context "Execute" {
        It "Sets ExitState to Cancelled" {
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_Q }
            
            $command.Execute($keyPress, $context)
            
            $state.ExitState | Should -Be "Cancelled"
        }

        It "Stops the navigation loop" {
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_Q }
            
            $state.IsRunning | Should -Be $true # Initial state
            $command.Execute($keyPress, $context)
            $state.IsRunning | Should -Be $false
        }
    }
}
