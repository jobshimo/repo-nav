Describe "WindowSizeCalculator" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load the mock subclass dynamically AFTER base class is loaded
        . "$projectRoot\tests\Mocks\TestableWindowSizeCalculator.ps1"
    }

    BeforeEach {
        $calculator = [TestableWindowSizeCalculator]::new()
    }

    Context "Viewport Adjustment" {
        It "Keeps selection visible when scrolling down" {
            $calculator.AdjustViewportForSelection(10, 0, 10) | Should -Be 1
        }

        It "Keeps selection visible when scrolling up" {
            $calculator.AdjustViewportForSelection(5, 10, 10) | Should -Be 5
        }

        It "Does not change viewport if selection is visible" {
            $calculator.AdjustViewportForSelection(5, 0, 10) | Should -Be 0
        }
    }

    Context "Window Dimension Calculations" {
        BeforeEach {
            # Create a mock RawUI object structure
            $mockRawUI = [PSCustomObject]@{
                WindowSize = [PSCustomObject]@{
                    Height = 40
                    Width = 120
                }
            }
            $calculator.SetMockRawUI($mockRawUI)
        }

        It "CalculatePageSize adheres to MinPageSize" {
            $calculator.GetRawUI().WindowSize.Height = 10
            $calculator.CalculatePageSize(10) | Should -Be 1
        }

        It "CalculatePageSize adheres to MaxPageSize" {
            $calculator.GetRawUI().WindowSize.Height = 100
            $calculator.CalculatePageSize(5) | Should -Be 50
        }

        It "CalculatePageSize calculates correctly within bounds" {
            $calculator.GetRawUI().WindowSize.Height = 30
            # 30 - (5 + 7) = 18
            $calculator.CalculatePageSize(5) | Should -Be 18
        }
        
        It "GetWindowHeight returns mock value" {
            $calculator.GetRawUI().WindowSize.Height = 45
            $calculator.GetWindowHeight() | Should -Be 45
        }

        It "GetWindowWidth returns mock value" {
            $calculator.GetRawUI().WindowSize.Width = 80
            $calculator.GetWindowWidth() | Should -Be 80
        }
        
        It "CalculateInitialPageSize uses defaults" {
             $calculator.GetRawUI().WindowSize.Height = 40
             # 40 - 20 = 20
             $calculator.CalculateInitialPageSize() | Should -Be 20
        }
    }
    
    Context "Error Handling" {
        BeforeEach {
             # Set Mock to null to trigger catch blocks (assuming implementation throws on null RawUI or failure to access)
             # Our implementation throws "No UI" if GetRawUI returns null.
             $calculator.SetMockRawUI($null)
        }
        
        It "GetWindowHeight returns default on error" {
             $calculator.GetWindowHeight() | Should -Be 30
        }
        
        It "GetWindowWidth returns default on error" {
             $calculator.GetWindowWidth() | Should -Be 120
        }
        
        It "CalculatePageSize returns default on error" {
             $calculator.CalculatePageSize(5) | Should -Be 15
        }
        
        It "CalculateInitialPageSize returns default on error" {
             $calculator.CalculateInitialPageSize() | Should -Be 15
        }
    }
}
