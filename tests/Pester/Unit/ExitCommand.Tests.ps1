Describe "ExitCommand" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load MockCommonServices for New-MockKeyInfo
        . "$projectRoot\tests\Mocks\MockCommonServices.ps1"
        
        # Mock PowerShell commands
        Mock Start-Sleep {}
        Mock Write-Host {}
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
            $keyPress = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_Q)
            $command.CanExecute($keyPress, $context) | Should -Be $true
        }

        It "Returns true for ESC key" {
            $keyPress = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_ESC)
            $command.CanExecute($keyPress, $context) | Should -Be $true
        }

        It "Returns false for other keys" {
            $keyPress = New-MockKeyInfo -VirtualKeyCode 65 # A
            $command.CanExecute($keyPress, $context) | Should -Be $false
        }
    }

    Context "Execute" {
        It "Sets ExitState to Cancelled" {
            $keyPress = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_Q)
            
            $command.Execute($keyPress, $context)
            
            $state.ExitState | Should -Be "Cancelled"
        }

        It "Stops the navigation loop" {
            $keyPress = New-MockKeyInfo -VirtualKeyCode ([Constants]::KEY_Q)
            
            $state.IsRunning | Should -Be $true # Initial state
            $command.Execute($keyPress, $context)
            $state.IsRunning | Should -Be $false
        }
    }
}
