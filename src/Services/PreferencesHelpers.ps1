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
        $Renderer,
        
        [Parameter(Mandatory = $true)]
        $OptionSelector
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
            
            # Define preference items
            $preferenceItems = @(
                @{
                    Name = "Favorites Position"
                    CurrentValue = if ($preferences.display.favoritesOnTop) { "Top of list" } else { "Original position" }
                }
            )
            
            # Display preference items
            for ($i = 0; $i -lt $preferenceItems.Count; $i++) {
                $item = $preferenceItems[$i]
                $prefix = if ($i -eq $selectedOption) { ">" } else { " " }
                $color = if ($i -eq $selectedOption) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                
                Write-Host "  $prefix $($item.Name): $($item.CurrentValue)" -ForegroundColor $color
            }
            
            Write-Host ""
            
            # Back option
            $backIndex = $preferenceItems.Count
            $prefix = if ($selectedOption -eq $backIndex) { ">" } else { " " }
            $color = if ($selectedOption -eq $backIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
            Write-Host "  $prefix Back to main menu" -ForegroundColor $color
            
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
            
            Write-Host "  Use Arrows to navigate | Enter to change/select | Q to go back" -ForegroundColor ([Constants]::ColorHint)
            
            # Wait for input
            $key = $Console.ReadKey()
            
            switch ($key.VirtualKeyCode) {
                ([Constants]::KEY_UP_ARROW) {
                    if ($selectedOption -gt 0) {
                        $selectedOption--
                    } else {
                        $selectedOption = $preferenceItems.Count
                    }
                }
                
                ([Constants]::KEY_DOWN_ARROW) {
                    if ($selectedOption -lt $preferenceItems.Count) {
                        $selectedOption++
                    } else {
                        $selectedOption = 0
                    }
                }
                
                ([Constants]::KEY_ENTER) {
                    if ($selectedOption -eq 0) {
                        # Edit Favorites Position using OptionSelector
                        $favoritesOptions = @(
                            @{ DisplayText = "Top of list"; Value = $true },
                            @{ DisplayText = "Original position"; Value = $false }
                        )
                        
                        $currentValue = $preferences.display.favoritesOnTop
                        $newValue = $OptionSelector.ShowSelection(
                            "FAVORITES POSITION",
                            $favoritesOptions,
                            $currentValue,
                            "Back to preferences"
                        )
                        
                        # If user selected something (not cancelled)
                        if ($null -ne $newValue -and $newValue -ne $currentValue) {
                            $PreferencesService.SetPreference("display", "favoritesOnTop", $newValue)
                            $preferences = $PreferencesService.LoadPreferences()
                            
                            # Set confirmation message
                            $statusText = if ($newValue) { "Top of list" } else { "Original position" }
                            $confirmationMessage = "Favorites will be shown at: $statusText"
                            $confirmationTimeout = 2
                        }
                    }
                    elseif ($selectedOption -eq $preferenceItems.Count) {
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
