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
        $OptionSelector,

        [Parameter(Mandatory = $true)]
        $LocalizationService
    )
    
    # Helper for localization
    function Get-Loc([string]$key, [string]$default) {
        return $LocalizationService.Get($key)
    }

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
            $Renderer.RenderHeader($(Get-Loc "Pref.Title" "USER PREFERENCES"))
            Write-Host ""
            
            # Define preference items
            $preferenceItems = @()

            # 0: Language
            $preferenceItems += @{
                Id = "language"
                Name = $(Get-Loc "Pref.Language" "Language")
                CurrentValue = $LocalizationService.GetCurrentLanguage()
            }

            # 1: Favorites On Top
            $preferenceItems += @{
                Id = "favoritesOnTop"
                Name = $(Get-Loc "Pref.FavoritesPos" "Favorites Position")
                CurrentValue = if ($preferences.display.favoritesOnTop) { $(Get-Loc "Pref.Value.Top" "Top of list") } else { $(Get-Loc "Pref.Value.Original" "Original position") }
            }

            # 2: Background
            $preferenceItems += @{
                Id = "selectedBackground"
                Name = $(Get-Loc "Pref.SelectedBg" "Selected Item Background")
                CurrentValue = $preferences.display.selectedBackground
            }

            # 3: Delimiter
            $preferenceItems += @{
                Id = "selectedDelimiter"
                Name = $(Get-Loc "Pref.SelectedDelim" "Selected Item Delimiter")
                CurrentValue = $preferences.display.selectedDelimiter
            }

            # 4: Auto Git
            $preferenceItems += @{
                Id = "autoLoadGit"
                Name = $(Get-Loc "Pref.AutoLoadGit" "Auto-load Git Status (Favorites)")
                CurrentValue = if ($preferences.git.autoLoadFavoritesStatus) { $(Get-Loc "Pref.Value.Enabled" "Enabled") } else { $(Get-Loc "Pref.Value.Disabled" "Disabled") }
            }
            
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
            Write-Host "  $prefix $(Get-Loc "Pref.Back" "Back to main menu")" -ForegroundColor $color
            
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
                    if ($selectedOption -eq $preferenceItems.Count) {
                        $running = $false
                    } else {
                        # Logic based on selected item ID
                        $selectedItem = $preferenceItems[$selectedOption]
                        
                        if ($selectedItem.Id -eq "language") {
                            $langs = $LocalizationService.GetAvailableLanguages()
                            # Build menu options for OptionSelector
                            $langOptions = @()
                            foreach ($lang in $langs) {
                                $langOptions += @{ DisplayText = $lang; Value = $lang }
                            }
                            
                            $newValue = $OptionSelector.ShowSelection(
                                $(Get-Loc "Prompt.SelectLanguage" "Select Language"),
                                $langOptions,
                                $LocalizationService.GetCurrentLanguage(),
                                "Cancel"
                            )
                            
                            if ($null -ne $newValue) {
                                $LocalizationService.SetLanguage($newValue)
                                $PreferencesService.SetPreference("general", "language", $newValue)
                                $confirmationMessage = "Language changed to $newValue"
                                $confirmationTimeout = 5
                                # Reload preferences
                                $preferences = $PreferencesService.LoadPreferences()
                            }
                        }
                        elseif ($selectedItem.Id -eq "favoritesOnTop") {
                            $favoritesOptions = @(
                                @{ DisplayText = $(Get-Loc "Pref.Value.Top" "Top of list"); Value = $true },
                                @{ DisplayText = $(Get-Loc "Pref.Value.Original" "Original position"); Value = $false }
                            )
                            
                            $newValue = $OptionSelector.ShowSelection(
                                $(Get-Loc "Pref.FavoritesPos" "Favorites Position"),
                                $favoritesOptions,
                                $preferences.display.favoritesOnTop,
                                "Cancel"
                            )
                            
                            if ($null -ne $newValue) {
                                $PreferencesService.SetPreference("display", "favoritesOnTop", $newValue)
                                $confirmationMessage = "Updated favorites position"
                                $confirmationTimeout = 2
                                $preferences = $PreferencesService.LoadPreferences()
                            }
                        }
                        elseif ($selectedItem.Id -eq "selectedBackground") {
                            $bgOptions = @()
                            foreach ($bg in [Constants]::AvailableBackgroundColors) {
                                $displayText = if ($bg -eq 'None') { 'No background' } else { $bg }
                                $bgOptions += @{ DisplayText = $displayText; Value = $bg }
                            }

                            $newValue = $OptionSelector.ShowSelection(
                                $(Get-Loc "Pref.SelectedBg" "Selected Item Background"),
                                $bgOptions,
                                $preferences.display.selectedBackground,
                                "Cancel"
                            )

                            if ($null -ne $newValue) {
                                $PreferencesService.SetPreference("display", "selectedBackground", $newValue)
                                $confirmationMessage = "Updated background"
                                $confirmationTimeout = 2
                                $preferences = $PreferencesService.LoadPreferences()
                            }
                        }
                        elseif ($selectedItem.Id -eq "selectedDelimiter") {
                            $delimOptions = @()
                            foreach ($delim in [Constants]::AvailableDelimiters) {
                                $delimOptions += @{ DisplayText = $delim.Name; Value = $delim.Name }
                            }

                            $newValue = $OptionSelector.ShowSelection(
                                $(Get-Loc "Pref.SelectedDelim" "Selected Item Delimiter"),
                                $delimOptions,
                                $preferences.display.selectedDelimiter,
                                "Cancel"
                            )

                            if ($null -ne $newValue) {
                                $PreferencesService.SetPreference("display", "selectedDelimiter", $newValue)
                                $confirmationMessage = "Updated delimiter"
                                $confirmationTimeout = 2
                                $preferences = $PreferencesService.LoadPreferences()
                            }
                        }
                        elseif ($selectedItem.Id -eq "autoLoadGit") {
                             $autoLoadOptions = @(
                                @{ DisplayText = $(Get-Loc "Pref.Value.Enabled" "Enabled"); Value = $true },
                                @{ DisplayText = $(Get-Loc "Pref.Value.Disabled" "Disabled"); Value = $false }
                            )
                            
                            $newValue = $OptionSelector.ShowSelection(
                                $(Get-Loc "Pref.AutoLoadGit" "Auto-load Git Status"),
                                $autoLoadOptions,
                                $preferences.git.autoLoadFavoritesStatus,
                                "Cancel"
                            )
                            
                            if ($null -ne $newValue) {
                                $PreferencesService.SetPreference("git", "autoLoadFavoritesStatus", $newValue)
                                $confirmationMessage = "Updated auto-load settings"
                                $confirmationTimeout = 2
                                $preferences = $PreferencesService.LoadPreferences()
                            }
                        }
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
