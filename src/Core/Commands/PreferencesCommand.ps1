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

        # Define localization helper block
        $GetLoc = { param($key, $def) if ($LocalizationService) { return $LocalizationService.Get($key) } return $def }

        $preferences = $PreferencesService.LoadPreferences()
        $selectedOption = 0
        $running = $true
        $confirmationMessage = ""
        $confirmationTimeout = 0
        
        try {
            $Console.HideCursor()
            $fullRedrawNeeded = $true
            # Save cursor position to avoid full screen clearing
            $listStartTop = 0
            
            while ($running) {
                # 1. Render Layer
                if ($fullRedrawNeeded) {
                    $Console.ClearScreen()
                    $Renderer.RenderHeader((& $GetLoc "Pref.Title" "USER PREFERENCES"))
                    Write-Host ""
                    $listStartTop = $Console.GetCursorTop()
                    $fullRedrawNeeded = $false
                }
                
                $Console.SetCursorPosition(0, $listStartTop)

                # 2. Data Layer (Construct Menu Model)
                $preferenceItems = $this.GetPreferenceItems($preferences, $GetLoc, $LocalizationService)
                
                # 3. View Layer (Draw Menu)
                $this.RenderMenu($preferenceItems, $selectedOption, $GetLoc)
                
                # 4. Feedback Layer
                $this.RenderFeedback($confirmationMessage, $confirmationTimeout, $Renderer)
                if ($confirmationTimeout -gt 0) { $confirmationTimeout-- } else { $confirmationMessage = "" }
                
                Write-Host ""
                Write-Host "  Use Arrows to navigate | Enter to change/select | Q to go back" -ForegroundColor ([Constants]::ColorHint)
                
                # 5. Input Layer
                $key = $Console.ReadKey()
                
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        $selectedOption = if ($selectedOption -gt 0) { $selectedOption - 1 } else { $preferenceItems.Count }
                    }
                    
                    ([Constants]::KEY_DOWN_ARROW) {
                        $selectedOption = if ($selectedOption -lt $preferenceItems.Count) { $selectedOption + 1 } else { 0 }
                    }
                    
                    ([Constants]::KEY_ENTER) {
                        if ($selectedOption -eq $preferenceItems.Count) {
                            $running = $false
                        }
                        else {
                            # 6. Action Layer (Process Selection)
                            $selectedItem = $preferenceItems[$selectedOption]
                            $result = $this.HandleSelection($selectedItem, $preferences, $context, $GetLoc)
                            if ($result.Updated) {
                                $preferences = $PreferencesService.LoadPreferences()
                                $confirmationMessage = $result.Message
                                $confirmationTimeout = $result.Timeout
                                $fullRedrawNeeded = $true
                            }
                        }
                    }
                    
                    ([Constants]::KEY_Q) { $running = $false }
                    ([Constants]::KEY_ESC) { $running = $false }
                }
            }
        }
        finally {
            $Console.ShowCursor()
        }
        
        return $true
    }

    # Region: Helper Methods (Refactoring for SOLID/Clean Code)

    hidden [array] GetPreferenceItems($preferences, $GetLoc, $LocalizationService) {
        $items = @()

        # 0: Language
        $currentLang = $LocalizationService.GetCurrentLanguage()
        $langName = & $GetLoc "Lang.$currentLang" $currentLang
        $items += @{ Id = "language"; Name = (& $GetLoc "Pref.Language" "Language"); CurrentValue = $langName }

        # 1: Favorites On Top
        $favVal = if ($preferences.display.favoritesOnTop) { (& $GetLoc "Pref.Value.Top" "Top") } else { (& $GetLoc "Pref.Value.Original" "Original") }
        $items += @{ Id = "favoritesOnTop"; Name = (& $GetLoc "Pref.FavoritesPos" "Favorites Position"); CurrentValue = $favVal }

        # 2: Background
        $items += @{ Id = "selectedBackground"; Name = (& $GetLoc "Pref.SelectedBg" "Selected Item Background"); CurrentValue = $preferences.display.selectedBackground }

        # 3: Delimiter
        $items += @{ Id = "selectedDelimiter"; Name = (& $GetLoc "Pref.SelectedDelim" "Selected Item Delimiter"); CurrentValue = $preferences.display.selectedDelimiter }

        # 4: Auto Git
        $gitVal = if ($preferences.git.autoLoadFavoritesStatus) { (& $GetLoc "Pref.Value.Enabled" "Enabled") } else { (& $GetLoc "Pref.Value.Disabled" "Disabled") }
        $items += @{ Id = "autoLoadGit"; Name = (& $GetLoc "Pref.AutoLoadGit" "Auto-load Git Status"); CurrentValue = $gitVal }
        
        # 5: Menu Mode
        $menuModeDisplay = if ($preferences.display.menuMode) { $preferences.display.menuMode } else { "Full" }
        $items += @{ Id = "menuMode"; Name = (& $GetLoc "Pref.MenuMode" "Menu Display"); CurrentValue = $menuModeDisplay }

        # 6..N: Custom Menu Sections
        if ($preferences.display.menuMode -eq 'Custom' -and $preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                $sections = $preferences.display.menuSections
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
                    
                    $items += @{
                        Id           = "section_$secKey"
                        Name         = "  - $($sectionLabels[$secKey])"
                        CurrentValue = $valDisplay
                        IsSectionToggle = $true
                        SectionKey = $secKey
                        RawValue = $isEnabled
                    }
                }
        }
        return $items
    }

    hidden [void] RenderMenu([array]$items, [int]$selectedOption, $GetLoc) {
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $isSelected = ($i -eq $selectedOption)
            $prefix = if ($isSelected) { ">" } else { " " }
            $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
            
            Write-Host "  $prefix $( $item.Name): " -NoNewline -ForegroundColor $color
            
            if ($item.Id -eq "selectedBackground") {
                # Special handling for background preview
                $bgVal = $item.CurrentValue
                $bgDisplay = if ($bgVal -eq 'None') { & $GetLoc "Color.None" "No background" } else { & $GetLoc "Color.$bgVal" $bgVal }
                
                $fgColor = if ($bgVal -ne 'None' -and ($bgVal -as [System.ConsoleColor])) { $bgVal } else { $color }
                Write-Host $bgDisplay -ForegroundColor $fgColor
            }
            else {
                Write-Host $item.CurrentValue -ForegroundColor $color
            }
        }
        
        Write-Host ""
        $backIndex = $items.Count
        $prefix = if ($selectedOption -eq $backIndex) { ">" } else { " " }
        $color = if ($selectedOption -eq $backIndex) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        Write-Host "  $prefix $( & $GetLoc "Pref.Back" "Back to main menu")" -ForegroundColor $color
    }

    hidden [void] RenderFeedback([string]$msg, [int]$timeout, $Renderer) {
        Write-Host ""
        if ($msg -ne "" -and $timeout -gt 0) {
            $Renderer.RenderSuccess($msg.PadRight(60))
        } else {
            Write-Host (" " * 60)
        }
    }

    hidden [PSCustomObject] HandleSelection($item, $preferences, $context, $GetLoc) {
        $msg = ""
        $timeout = 0
        $updated = $false
        
        $Localization = $context.LocalizationService
        $PrefsService = $context.RepoManager.PreferencesService
        $OptionSelector = $context.OptionSelector

        if ($item.Id -eq "language") {
            $langs = $Localization.GetAvailableLanguages()
            $opts = @()
            foreach ($l in $langs) { 
                $d = & $GetLoc "Lang.$l" $l
                $opts += @{ DisplayText = "$d ($l)"; Value = $l } 
            }
            
            $newVal = $OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectLanguage"), $opts, $Localization.GetCurrentLanguage(), "Cancel")
            if ($newVal) {
                $Localization.SetLanguage($newVal)
                $PrefsService.SetPreference("general", "language", $newVal)
                $msg = (& $GetLoc "Msg.LanguageChanged" "Language changed to {0}") -f $newVal
                $updated = $true
                $timeout = 5
            }
        }
        elseif ($item.Id -eq "favoritesOnTop") {
            $opts = @( @{ DisplayText = (& $GetLoc "Pref.Value.Top"); Value = $true }, @{ DisplayText = (& $GetLoc "Pref.Value.Original"); Value = $false } )
            $newVal = $OptionSelector.ShowSelection((& $GetLoc "Pref.FavoritesPos"), $opts, $preferences.display.favoritesOnTop, "Cancel")
            if ($null -ne $newVal) {
                 $PrefsService.SetPreference("display", "favoritesOnTop", $newVal)
                 $msg = (& $GetLoc "Msg.FavoritesPosUpdated")
                 $updated = $true
                 $timeout = 2
            }
        }
        elseif ($item.Id -eq "selectedBackground") {
            $opts = @()
            foreach ($bg in [Constants]::AvailableBackgroundColors) {
                 $txt = if ($bg -eq 'None') { & $GetLoc "Color.None" "No background" } else { & $GetLoc "Color.$bg" $bg }
                 $opts += @{ DisplayText = $txt; Value = $bg }
            }
            $newVal = $OptionSelector.ShowSelection((& $GetLoc "Pref.SelectedBg"), $opts, $preferences.display.selectedBackground, "Cancel")
            if ($newVal) {
                 $PrefsService.SetPreference("display", "selectedBackground", $newVal)
                 $msg = (& $GetLoc "Msg.BackgroundUpdated")
                 $updated = $true
                 $timeout = 2
            }
        }
        elseif ($item.Id -eq "selectedDelimiter") {
             $opts = @()
             foreach ($d in [Constants]::AvailableDelimiters) { $opts += @{ DisplayText = $d.Name; Value = $d.Name } }
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Pref.SelectedDelim"), $opts, $preferences.display.selectedDelimiter, "Cancel")
             if ($newVal) {
                 $PrefsService.SetPreference("display", "selectedDelimiter", $newVal)
                 $msg = (& $GetLoc "Msg.DelimiterUpdated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.Id -eq "autoLoadGit") {
             $opts = @( @{ DisplayText = (& $GetLoc "Pref.Value.Enabled"); Value = $true }, @{ DisplayText = (& $GetLoc "Pref.Value.Disabled"); Value = $false } )
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Pref.AutoLoadGit"), $opts, $preferences.git.autoLoadFavoritesStatus, "Cancel")
             if ($null -ne $newVal) {
                 $PrefsService.SetPreference("git", "autoLoadFavoritesStatus", $newVal)
                 $msg = (& $GetLoc "Msg.AutoLoadUpdated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.Id -eq "menuMode") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.MenuMode.Full"); Value = "Full" },
                 @{ DisplayText = (& $GetLoc "Pref.MenuMode.Minimal"); Value = "Minimal" },
                 @{ DisplayText = (& $GetLoc "Pref.MenuMode.Custom"); Value = "Custom" },
                 @{ DisplayText = (& $GetLoc "Pref.MenuMode.Hidden"); Value = "Hidden" }
             )
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Pref.MenuMode"), $opts, $preferences.display.menuMode, "Cancel")
             if ($newVal) {
                 $PrefsService.SetPreference("display", "menuMode", $newVal)
                 $msg = (& $GetLoc "Msg.MenuModeUpdated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.IsSectionToggle) {
             $sec = $item.SectionKey
             $newVal = -not $item.RawValue
             $preferences.display.menuSections.$sec = $newVal
             $PrefsService.SavePreferences($preferences)
             $msg = (& $GetLoc "Msg.SectionToggled" -f $sec)
             $updated = $true
             $timeout = 1
        }

        return [PSCustomObject]@{ Updated = $updated; Message = $msg; Timeout = $timeout }
    }
}
