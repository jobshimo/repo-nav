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
                },
                @{
                    Name = "Selected Item Background"
                    CurrentValue = $preferences.display.selectedBackground
                },
                @{
                    Name = "Selected Item Delimiter"
                    CurrentValue = $preferences.display.selectedDelimiter
                },
                @{
                    Name = "Auto-load Git Status (Favorites)"
                    CurrentValue = if ($preferences.git.autoLoadFavoritesStatus) { "Enabled" } else { "Disabled" }
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
                    elseif ($selectedOption -eq 1) {
                        # Edit Selected Background using OptionSelector
                        $backgroundOptions = @()
                        foreach ($bg in [Constants]::AvailableBackgroundColors) {
                            $displayText = if ($bg -eq 'None') { 'No background' } else { $bg }
                            $backgroundOptions += @{ DisplayText = $displayText; Value = $bg }
                        }
                        
                        $currentValue = $preferences.display.selectedBackground
                        $newValue = $OptionSelector.ShowSelection(
                            "SELECTED ITEM BACKGROUND",
                            $backgroundOptions,
                            $currentValue,
                            "Back to preferences"
                        )
                        
                        # If user selected something (not cancelled)
                        if ($null -ne $newValue -and $newValue -ne $currentValue) {
                            $PreferencesService.SetPreference("display", "selectedBackground", $newValue)
                            $preferences = $PreferencesService.LoadPreferences()
                            
                            # Set confirmation message
                            $statusText = if ($newValue -eq 'None') { "No background" } else { $newValue }
                            $confirmationMessage = "Background color changed to: $statusText"
                            $confirmationTimeout = 2
                        }
                    }
                    elseif ($selectedOption -eq 2) {
                        # Edit Selected Delimiter using OptionSelector
                        $delimiterOptions = @()
                        foreach ($delim in [Constants]::AvailableDelimiters) {
                            $delimiterOptions += @{ DisplayText = $delim.Name; Value = $delim.Name }
                        }
                        
                        $currentValue = $preferences.display.selectedDelimiter
                        $newValue = $OptionSelector.ShowSelection(
                            "SELECTED ITEM DELIMITER",
                            $delimiterOptions,
                            $currentValue,
                            "Back to preferences"
                        )
                        
                        # If user selected something (not cancelled)
                        if ($null -ne $newValue -and $newValue -ne $currentValue) {
                            $PreferencesService.SetPreference("display", "selectedDelimiter", $newValue)
                            $preferences = $PreferencesService.LoadPreferences()
                            
                            # Set confirmation message
                            $confirmationMessage = "Delimiter changed to: $newValue"
                            $confirmationTimeout = 2
                        }
                    }
                    elseif ($selectedOption -eq 3) {
                        $autoLoadOptions = @(
                            @{ DisplayText = "Enabled"; Value = $true },
                            @{ DisplayText = "Disabled"; Value = $false }
                        )
                        
                        $currentValue = $preferences.git.autoLoadFavoritesStatus
                        $newValue = $OptionSelector.ShowSelection(
                            "AUTO-LOAD GIT STATUS (FAVORITES ONLY)",
                            $autoLoadOptions,
                            $currentValue,
                            "Back to preferences"
                        )
                        
                        if ($null -ne $newValue -and $newValue -ne $currentValue) {
                            $PreferencesService.SetPreference("git", "autoLoadFavoritesStatus", $newValue)
                            $preferences = $PreferencesService.LoadPreferences()
                            
                            $statusText = if ($newValue) { "Enabled" } else { "Disabled" }
                            $confirmationMessage = "Auto-load git status: $statusText"
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
