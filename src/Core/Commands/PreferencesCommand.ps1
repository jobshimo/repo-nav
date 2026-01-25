# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class PreferencesCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open preferences menu (U)"
    }

    [bool] CanExecute([object]$keyPress, [hashtable]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_U
    }

    [void] Execute([object]$keyPress, [hashtable]$context) {
        $state = $context.State
        
        # Stop the navigation loop to allow interactive menu
        $state.Stop()
        
        try {
            # Show preferences menu
            $this.InvokePreferencesMenu($context)
            
            # Reload repositories after preferences change
            # (sorting order may have changed)
            $repoManager = $context.RepoManager
            if ($null -ne $repoManager) {
                $repoManager.LoadRepositories($context.BasePath)
                $updatedRepos = $repoManager.GetRepositories()
                $state.SetRepositories($updatedRepos)
                
                # Reset selection to first item after preference changes
                $state.SetCurrentIndex(0)
            }
            
            # Mark for full redraw
            $state.MarkForFullRedraw()
        }
        finally {
            # Resume navigation loop
            $state.Resume()
        }
    }

    hidden [bool] InvokePreferencesMenu($context) {
        $PreferencesService = $context.RepoManager.PreferencesService
        $Console = $context.Console
        $Renderer = $context.Renderer
        $OptionSelector = $context.OptionSelector
        $LocalizationService = $context.LocalizationService

        # Helper for localization
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        $preferences = $PreferencesService.LoadPreferences()
        $selectedOption = 0
        $running = $true
        $confirmationMessage = ""
        $confirmationTimeout = 0
        
        try {
            $Console.HideCursor()
            
            # Initial draw state
            $fullRedrawNeeded = $true
            
            # Save cursor position to avoid full screen clearing
            $listStartTop = 0
            
            while ($running) {
                if ($fullRedrawNeeded) {
                    # Force full clear and header render
                    $Console.ClearScreen()
                    $Renderer.RenderHeader((& $GetLoc "Pref.Title" "USER PREFERENCES"))
                    Write-Host ""
                    $listStartTop = $Console.GetCursorTop()
                    $fullRedrawNeeded = $false
                }
                
                # Reset cursor to start of list
                $Console.SetCursorPosition(0, $listStartTop)

                # Define preference items (re-evaluate each time as values change)
                $preferenceItems = @()

                # 0: Language
                $currentLang = $LocalizationService.GetCurrentLanguage()
                $langName = & $GetLoc "Lang.$currentLang" $currentLang
                
                $preferenceItems += @{
                    Id           = "language"
                    Name         = (& $GetLoc "Pref.Language" "Language")
                    CurrentValue = $langName
                }

                # 1: Favorites On Top
                $preferenceItems += @{
                    Id           = "favoritesOnTop"
                    Name         = (& $GetLoc "Pref.FavoritesPos" "Favorites Position")
                    CurrentValue = if ($preferences.display.favoritesOnTop) { (& $GetLoc "Pref.Value.Top" "Top of list") } else { (& $GetLoc "Pref.Value.Original" "Original position") }
                }

                # 2: Background
                $preferenceItems += @{
                    Id           = "selectedBackground"
                    Name         = (& $GetLoc "Pref.SelectedBg" "Selected Item Background")
                    CurrentValue = $preferences.display.selectedBackground
                }

                # 3: Delimiter
                $preferenceItems += @{
                    Id           = "selectedDelimiter"
                    Name         = (& $GetLoc "Pref.SelectedDelim" "Selected Item Delimiter")
                    CurrentValue = $preferences.display.selectedDelimiter
                }

                # 4: Auto Git
                $preferenceItems += @{
                    Id           = "autoLoadGit"
                    Name         = (& $GetLoc "Pref.AutoLoadGit" "Auto-load Git Status (Favorites)")
                    CurrentValue = if ($preferences.git.autoLoadFavoritesStatus) { (& $GetLoc "Pref.Value.Enabled" "Enabled") } else { (& $GetLoc "Pref.Value.Disabled" "Disabled") }
                }
                
                # 5: Menu Mode
                $preferenceItems += @{
                    Id           = "menuMode"
                    Name         = (& $GetLoc "Pref.MenuMode" "Menu Display")
                    CurrentValue = if ($preferences.display.menuMode) { $preferences.display.menuMode } else { "Full" }
                }

                # 6..N: Custom Menu Sections (Dynamic)
                if ($preferences.display.menuMode -eq 'Custom' -and $preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                     $sections = $preferences.display.menuSections
                     
                     # Define sections to show
                     $sectionKeys = @("navigation", "alias", "modules", "repository", "git")
                     $sectionLabels = @{
                        "navigation" = (& $GetLoc "UI.Group.Nav" "Navigation");
                        "alias"      = "Alias";
                        "modules"    = (& $GetLoc "UI.Group.Modules" "Modules");
                        "repository" = (& $GetLoc "UI.Group.Repo" "Repository");
                        "git"        = "Git Status"
                     }

                     foreach ($secKey in $sectionKeys) {
                         $isEnabled = if ($sections.PSObject.Properties.Name -contains $secKey) { $sections.$secKey } else { $true }
                         $valDisplay = if ($isEnabled) { "[x] $(& $GetLoc "Pref.Value.Show" "Show")" } else { "[ ] $(& $GetLoc "Pref.Value.Show" "Show")" }
                         
                         $preferenceItems += @{
                             Id           = "section_$secKey"
                             Name         = "  - $($sectionLabels[$secKey])" # Indented
                             CurrentValue = $valDisplay
                             IsSectionToggle = $true
                             SectionKey = $secKey
                             RawValue = $isEnabled
                         }
                     }
                }
                
                # Display preference items
                for ($i = 0; $i -lt $preferenceItems.Count; $i++) {
                    $item = $preferenceItems[$i]
                    $prefix = if ($i -eq $selectedOption) { ">" } else { " " }
                    $color = if ($i -eq $selectedOption) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                    
                    Write-Host "  $prefix $( $item.Name): " -NoNewline -ForegroundColor $color
                    
                    if ($item.Id -eq "selectedBackground") {
                        # Special handling for background color: translate and preview
                        $bgVal = $item.CurrentValue
                        $bgDisplay = if ($bgVal -eq 'None') { & $GetLoc "Color.None" "No background" } else { & $GetLoc "Color.$bgVal" $bgVal }
                        
                        if ($bgVal -ne 'None' -and ($bgVal -as [System.ConsoleColor])) {
                            Write-Host $bgDisplay -ForegroundColor $bgVal
                        }
                        else {
                            Write-Host $bgDisplay -ForegroundColor $color
                        }
                    }
                    else {
                        Write-Host $item.CurrentValue -ForegroundColor $color
                    }
                }
                
                Write-Host ""
                
                # Back option
                $backIndex = $preferenceItems.Count
                $prefix = if ($selectedOption -eq $backIndex) { ">" } else { " " }
                $color = if ($selectedOption -eq $backIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                Write-Host "  $prefix $( & $GetLoc "Pref.Back" "Back to main menu")" -ForegroundColor $color
                
                Write-Host ""
                
                # Show confirmation message OR placeholder to maintain layout stability
                if ($confirmationMessage -ne "" -and $confirmationTimeout -gt 0) {
                    $Renderer.RenderSuccess($confirmationMessage.PadRight(60))
                    $confirmationTimeout--
                    if ($confirmationTimeout -eq 0) {
                        $confirmationMessage = ""
                    }
                }
                else {
                    # Print blank line to overwrite any previous message and keep footer stable
                    Write-Host (" " * 60)
                }
                Write-Host ""
                
                Write-Host "  Use Arrows to navigate | Enter to change/select | Q to go back" -ForegroundColor ([Constants]::ColorHint)
                
                # Wait for input
                $key = $Console.ReadKey()
                
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        if ($selectedOption -gt 0) {
                            $selectedOption--
                        }
                        else {
                            $selectedOption = $preferenceItems.Count
                        }
                    }
                    
                    ([Constants]::KEY_DOWN_ARROW) {
                        if ($selectedOption -lt $preferenceItems.Count) {
                            $selectedOption++
                        }
                        else {
                            $selectedOption = 0
                        }
                    }
                    
                    ([Constants]::KEY_ENTER) {
                        if ($selectedOption -eq $preferenceItems.Count) {
                            $running = $false
                        }
                        else {
                            # Logic based on selected item ID
                            $selectedItem = $preferenceItems[$selectedOption]
                            
                            if ($selectedItem.Id -eq "language") {
                                $langs = $LocalizationService.GetAvailableLanguages()
                                $langOptions = @()
                                foreach ($lang in $langs) {
                                    $desc = & $GetLoc "Lang.$lang" $lang
                                    $langOptions += @{ DisplayText = "$desc ($lang)"; Value = $lang }
                                }
                                
                                $newValue = $OptionSelector.ShowSelection(
                                    (& $GetLoc "Prompt.SelectLanguage" "Select Language"),
                                    $langOptions,
                                    $LocalizationService.GetCurrentLanguage(),
                                    "Cancel"
                                )
                                
                                if ($null -ne $newValue) {
                                    $LocalizationService.SetLanguage($newValue)
                                    $PreferencesService.SetPreference("general", "language", $newValue)
                                    $confirmationMessage = (& $GetLoc "Msg.LanguageChanged" "Language changed to {0}") -f $newValue
                                    $confirmationTimeout = 5
                                    $preferences = $PreferencesService.LoadPreferences()
                                }
                                $fullRedrawNeeded = $true
                            }
                            elseif ($selectedItem.Id -eq "favoritesOnTop") {
                                $favoritesOptions = @(
                                    @{ DisplayText = (& $GetLoc "Pref.Value.Top" "Top of list"); Value = $true },
                                    @{ DisplayText = (& $GetLoc "Pref.Value.Original" "Original position"); Value = $false }
                                )
                                
                                $newValue = $OptionSelector.ShowSelection(
                                    (& $GetLoc "Pref.FavoritesPos" "Favorites Position"),
                                    $favoritesOptions,
                                    $preferences.display.favoritesOnTop,
                                    "Cancel"
                                )
                                
                                if ($null -ne $newValue) {
                                    $PreferencesService.SetPreference("display", "favoritesOnTop", $newValue)
                                    $confirmationMessage = (& $GetLoc "Msg.FavoritesPosUpdated" "Updated favorites position")
                                    $confirmationTimeout = 2
                                    $preferences = $PreferencesService.LoadPreferences()
                                }
                                $fullRedrawNeeded = $true
                            }
                            elseif ($selectedItem.Id -eq "selectedBackground") {
                                $bgOptions = @()
                                foreach ($bg in [Constants]::AvailableBackgroundColors) {
                                    if ($bg -eq 'None') {
                                        $displayText = & $GetLoc "Color.None" "No background"
                                    }
                                    else {
                                        $displayText = & $GetLoc "Color.$bg" $bg
                                    }
                                    $bgOptions += @{ DisplayText = $displayText; Value = $bg }
                                }

                                $newValue = $OptionSelector.ShowSelection(
                                    (& $GetLoc "Pref.SelectedBg" "Selected Item Background"),
                                    $bgOptions,
                                    $preferences.display.selectedBackground,
                                    "Cancel"
                                )

                                if ($null -ne $newValue) {
                                    $PreferencesService.SetPreference("display", "selectedBackground", $newValue)
                                    $confirmationMessage = (& $GetLoc "Msg.BackgroundUpdated" "Updated background")
                                    $confirmationTimeout = 2
                                    $preferences = $PreferencesService.LoadPreferences()
                                }
                                $fullRedrawNeeded = $true
                            }
                            elseif ($selectedItem.Id -eq "selectedDelimiter") {
                                $delimOptions = @()
                                foreach ($delim in [Constants]::AvailableDelimiters) {
                                    $delimOptions += @{ DisplayText = $delim.Name; Value = $delim.Name }
                                }

                                $newValue = $OptionSelector.ShowSelection(
                                    (& $GetLoc "Pref.SelectedDelim" "Selected Item Delimiter"),
                                    $delimOptions,
                                    $preferences.display.selectedDelimiter,
                                    "Cancel"
                                )

                                if ($null -ne $newValue) {
                                    $PreferencesService.SetPreference("display", "selectedDelimiter", $newValue)
                                    $confirmationMessage = (& $GetLoc "Msg.DelimiterUpdated" "Updated delimiter")
                                    $confirmationTimeout = 2
                                    $preferences = $PreferencesService.LoadPreferences()
                                }
                                $fullRedrawNeeded = $true
                            }
                            elseif ($selectedItem.Id -eq "autoLoadGit") {
                                $autoLoadOptions = @(
                                    @{ DisplayText = (& $GetLoc "Pref.Value.Enabled" "Enabled"); Value = $true },
                                    @{ DisplayText = (& $GetLoc "Pref.Value.Disabled" "Disabled"); Value = $false }
                                )
                                
                                $newValue = $OptionSelector.ShowSelection(
                                    (& $GetLoc "Pref.AutoLoadGit" "Auto-load Git Status"),
                                    $autoLoadOptions,
                                    $preferences.git.autoLoadFavoritesStatus,
                                    "Cancel"
                                )
                                
                                if ($null -ne $newValue) {
                                    $PreferencesService.SetPreference("git", "autoLoadFavoritesStatus", $newValue)
                                    $confirmationMessage = (& $GetLoc "Msg.AutoLoadUpdated" "Updated auto-load settings")
                                    $confirmationTimeout = 2
                                    $preferences = $PreferencesService.LoadPreferences()
                                }
                                $fullRedrawNeeded = $true
                            }
                            elseif ($selectedItem.Id -eq "menuMode") {
                                $menuOptions = @(
                                    @{ DisplayText = (& $GetLoc "Pref.MenuMode.Full" "Full (All commands)"); Value = "Full" },
                                    @{ DisplayText = (& $GetLoc "Pref.MenuMode.Minimal" "Minimal (Navigation only)"); Value = "Minimal" },
                                    @{ DisplayText = (& $GetLoc "Pref.MenuMode.Custom" "Custom (Select sections)"); Value = "Custom" },
                                    @{ DisplayText = (& $GetLoc "Pref.MenuMode.Hidden" "Hidden (Hide menu)"); Value = "Hidden" }
                                )
                                
                                $newValue = $OptionSelector.ShowSelection(
                                    (& $GetLoc "Pref.MenuMode" "Menu Display"),
                                    $menuOptions,
                                    $preferences.display.menuMode,
                                    "Cancel"
                                )
                                
                                if ($null -ne $newValue) {
                                    $PreferencesService.SetPreference("display", "menuMode", $newValue)
                                    $confirmationMessage = (& $GetLoc "Msg.MenuModeUpdated" "Updated menu mode")
                                    $confirmationTimeout = 2
                                    $preferences = $PreferencesService.LoadPreferences()
                                }
                                $fullRedrawNeeded = $true
                            }
                            elseif ($selectedItem.IsSectionToggle) {
                                # Toggle the boolean value
                                $secKey = $selectedItem.SectionKey
                                $newVal = -not $selectedItem.RawValue
                                
                                # Access nested object carefully
                                if (-not ($preferences.display.PSObject.Properties.Name -contains 'menuSections')) {
                                    # Use normalized preferences if sections missing (shouldn't save, but in memory)
                                    # Actually, we need to persist change.
                                    # Ideally we should use SetPreference but it supports only 2 levels (section, key).
                                    # We might need a generic way or update entire object manually.
                                    # $state.MarkForFullRedraw() # Removed to avoid error: Variable is not assigned
                                }
                                
                                # The PreferencesService.SetPreference is simple: SetPreference(section, key, value)
                                # But we need to set display.menuSections.navigation
                                # Let's update the memory object and save the whole thing.
                                
                                $preferences.display.menuSections.$secKey = $newVal
                                $PreferencesService.SavePreferences($preferences)
                                
                                $confirmationMessage = (& $GetLoc "Msg.SectionToggled" "Toggled {0}") -f $secKey
                                $confirmationTimeout = 1
                                # Reload to ensure consistency
                                $preferences = $PreferencesService.LoadPreferences()
                                $fullRedrawNeeded = $true
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
}
