<#
.SYNOPSIS
    Interactive helpers for user preferences menu
#>

function Show-PreferencesMenu {
    param(
        [Parameter(Mandatory = $true)]
        $PreferencesService,
        
        [Parameter(Mandatory = $true)]
        $Console,
        
        [Parameter(Mandatory = $true)]
        $Renderer
    )
    
    $preferences = $PreferencesService.LoadPreferences()
    $selectedOption = 0
    $running = $true
    $confirmationMessage = ""
    $confirmationTimeout = 0
    
    try {
        $Console.HideCursor()
        
        while ($running) {
            # Clear and render preferences menu
            $Console.ClearScreen()
            $Renderer.RenderHeader("USER PREFERENCES")
            Write-Host ""
            
            # Display preferences
            $option1 = "  Favorites Position: " + $(if ($preferences.display.favoritesOnTop) { "Top of list" } else { "Original position" })
            $option2 = "  Back to main menu"
            
            if ($selectedOption -eq 0) {
                Write-Host "> $option1" -ForegroundColor Yellow
            } else {
                Write-Host "  $option1" -ForegroundColor Gray
            }
            
            Write-Host ""
            
            if ($selectedOption -eq 1) {
                Write-Host "> $option2" -ForegroundColor Yellow
            } else {
                Write-Host "  $option2" -ForegroundColor Gray
            }
            
            Write-Host ""
            
            # Show confirmation message if exists
            if ($confirmationMessage -ne "" -and $confirmationTimeout -gt 0) {
                $Renderer.RenderSuccess($confirmationMessage)
                Write-Host ""
                $confirmationTimeout--
                if ($confirmationTimeout -eq 0) {
                    $confirmationMessage = ""
                }
            }
            
            Write-Host "  Use Arrows to navigate | Enter to toggle/select | Q to go back" -ForegroundColor DarkGray
            
            # Wait for input
            $key = $Console.ReadKey()
            
            switch ($key.VirtualKeyCode) {
                ([Constants]::KEY_UP_ARROW) {
                    if ($selectedOption -gt 0) {
                        $selectedOption--
                    } else {
                        $selectedOption = 1
                    }
                }
                
                ([Constants]::KEY_DOWN_ARROW) {
                    if ($selectedOption -lt 1) {
                        $selectedOption++
                    } else {
                        $selectedOption = 0
                    }
                }
                
                ([Constants]::KEY_ENTER) {
                    if ($selectedOption -eq 0) {
                        # Toggle favorites position
                        [bool]$newValue = -not $preferences.display.favoritesOnTop
                        $PreferencesService.SetPreference("display", "favoritesOnTop", $newValue)
                        $preferences = $PreferencesService.LoadPreferences()
                        
                        # Set confirmation message
                        $statusText = if ($newValue) { "Top of list" } else { "Original position" }
                        $confirmationMessage = "Favorites will be shown at: $statusText"
                        $confirmationTimeout = 2
                    }
                    elseif ($selectedOption -eq 1) {
                        # Back to main menu
                        $running = $false
                    }
                }
                
                ([Constants]::KEY_Q) {
                    $running = $false
                }
                
                ([Constants]::KEY_ESC) {
                    $running = $false
                }
            }
        }
    }
    finally {
        $Console.ShowCursor()
    }
    
    return $true
}
