# IMPORTANT: INavigationCommand.ps1 must be loaded BEFORE this file

class PreferencesCommand : INavigationCommand {
    [string] GetDescription() {
        return "Open preferences menu (U)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_U
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
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
            
            # Viewport State
            $viewportStart = 0
            
            while ($running) {
                try {
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
                    # Add "Back" as a pseudo-item for consistent navigation
                    $backItem = @{ Id = "BACK_BUTTON"; Name = (& $GetLoc "Pref.Back" "Back to main menu"); CurrentValue = ""; IsAction = $true }
                    $allItems = $preferenceItems + $backItem
                    
                    # Dynamic Page Size Calculation
                    # Header lines (approx 3) + Footer lines (2: Separator + Text) 
                    # Safety margin 1
                    $reserved = $listStartTop + 3 
                    $reservedFooter = 2 # Separator + Message
                    
                    $winHeight = $Console.GetWindowHeight() 
                    $maxPageSize = $winHeight - ($reserved + $reservedFooter)
                    if ($maxPageSize -lt 5) { $maxPageSize = 5 } # Min size
                    
                    $pageSize = $maxPageSize
                    
                    # 3. View Layer (Draw Menu)
                    $this.RenderMenu($Console, $allItems, $selectedOption, $listStartTop, $viewportStart, $pageSize, $GetLoc)
                    
                    # 4. Feedback / Footer Layer
                    # Footer is always at Start + PageSize
                    $footerLine = $listStartTop + $pageSize
                    $this.RenderFooter($Console, $confirmationMessage, $confirmationTimeout, $footerLine)
                    
                    if ($confirmationTimeout -gt 0) { $confirmationTimeout-- } else { $confirmationMessage = "" }
                    
                    # 5. Input Layer
                    $key = $Console.ReadKey()
                    
                    switch ($key.VirtualKeyCode) {
                        ([Constants]::KEY_UP_ARROW) {
                            if ($selectedOption -gt 0) { 
                                $selectedOption-- 
                                if ($selectedOption -lt $viewportStart) {
                                    $viewportStart = $selectedOption
                                }
                            } else {
                                # Wrap to bottom
                                $selectedOption = $allItems.Count - 1
                                $viewportStart = [Math]::Max(0, $allItems.Count - $pageSize)
                            }
                        }
                        
                        ([Constants]::KEY_DOWN_ARROW) {
                            if ($selectedOption -lt ($allItems.Count - 1)) { 
                                $selectedOption++ 
                                if ($selectedOption -ge ($viewportStart + $pageSize)) {
                                    $viewportStart = $selectedOption - $pageSize + 1
                                }
                            } else {
                                # Wrap to top
                                $selectedOption = 0
                                $viewportStart = 0
                            }
                        }

                        ([Constants]::KEY_LEFT_ARROW) {
                             $running = $false
                        }
                        
                        ([Constants]::KEY_ENTER) {
                             $selectedItem = $allItems[$selectedOption]
                             if ($selectedItem.Id -eq "BACK_BUTTON") {
                                 $running = $false
                             }
                             else {
                                # 6. Action Layer (Process Selection)
                                $result = $this.HandleSelection($selectedItem, $preferences, $context, $GetLoc)
                                
                                # Always redraw after interaction because OptionSelector dirties the screen
                                $fullRedrawNeeded = $true
                                $viewportStart = 0 # Reset view on redraw usually safer
                                
                                if ($result.Updated) {
                                    $preferences = $PreferencesService.LoadPreferences()
                                    $confirmationMessage = $result.Message
                                    $confirmationTimeout = $result.Timeout
                                }
                            }
                        }
                        
                        ([Constants]::KEY_Q) { $running = $false }
                        ([Constants]::KEY_ESC) { $running = $false }
                    }
                }
                catch {
                    $running = $false
                    $Console.ClearScreen()
                    Write-Host "ERROR IN PREFERENCES MENU:" -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
                    Write-Host "Press any key to exit..."
                    $Console.ReadKey() | Out-Null
                }
            }
        }
        finally {
            $Console.ShowCursor()
        }
        
        return $true
    }

    # Region: Helper Methods
    
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

        # 3.1: Alias Position
        $posValKey = if ($preferences.display.aliasPosition -eq "Before") { "Pref.Value.Before" } else { "Pref.Value.After" }
        $posVal = & $GetLoc $posValKey $preferences.display.aliasPosition
        $items += @{ Id = "aliasPosition"; Name = (& $GetLoc "Pref.AliasPosition" "Alias Position"); CurrentValue = $posVal }
        
        # 3.2: Alias Separator
        $sepMap = @{
            " - " = "Pref.Value.SepHyphen"
            " : " = "Pref.Value.SepColon"
            " | " = "Pref.Value.SepPipe"
            "None" = "Pref.Value.None"
        }
        $sepKey = if ($sepMap.ContainsKey($preferences.display.aliasSeparator)) { $sepMap[$preferences.display.aliasSeparator] } else { "Pref.Value.SepHyphen" }
        $sepVal = & $GetLoc $sepKey $preferences.display.aliasSeparator
        $items += @{ Id = "aliasSeparator"; Name = (& $GetLoc "Pref.AliasSeparator" "Alias Separator"); CurrentValue = $sepVal }
        
        # 3.3: Alias Wrapper
        $wrapMap = @{
            "None" = "Pref.Value.None"
            "Parens" = "Pref.Value.WrapParens"
            "Brackets" = "Pref.Value.WrapBrackets"
            "Braces" = "Pref.Value.WrapBraces"
        }
        $wrapKey = if ($wrapMap.ContainsKey($preferences.display.aliasWrapper)) { $wrapMap[$preferences.display.aliasWrapper] } else { "Pref.Value.None" }
        $wrapVal = & $GetLoc $wrapKey $preferences.display.aliasWrapper
        $items += @{ Id = "aliasWrapper"; Name = (& $GetLoc "Pref.AliasWrapper" "Alias Style"); CurrentValue = $wrapVal }

        # 4: Auto Git
        $mode = $preferences.git.autoLoadGitStatusMode
        if (-not $mode) { $mode = "None" }
        $displayKey = "Pref.AutoLoadGit.$mode"
        $display = & $GetLoc $displayKey $mode
        $items += @{ Id = "autoLoadGit"; Name = (& $GetLoc "Pref.AutoLoadGit" "Auto-load Git Status"); CurrentValue = $display }
        
        # 5: Menu Mode
        $menuModeDisplay = if ($preferences.display.menuMode) { $preferences.display.menuMode } else { "Full" }
        $items += @{ Id = "menuMode"; Name = (& $GetLoc "Pref.MenuMode" "Menu Display"); CurrentValue = $menuModeDisplay }

        # 6..N: Custom Menu Sections
        if ($preferences.display.menuMode -eq 'Custom' -and $preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                $sections = $preferences.display.menuSections
                $sectionKeys = @("navigation", "alias", "modules", "repository", "git", "tools")
                $sectionLabels = @{
                "navigation" = (& $GetLoc "UI.Group.Nav" "Navigation");
                "alias"      = "Alias";
                "modules"    = (& $GetLoc "UI.Group.Modules" "Modules");
                "repository" = (& $GetLoc "UI.Group.Repo" "Repository");
                "git"        = "Git Status";
                "tools"      = (& $GetLoc "UI.Group.Tools" "Tools")
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


    hidden [void] RenderMenu([ConsoleHelper]$Console, [array]$items, [int]$selectedOption, [int]$startTop, [int]$viewportStart, [int]$pageSize, $GetLoc) {
        for ($i = 0; $i -lt $pageSize; $i++) {
            $Console.SetCursorPosition(0, $startTop + $i)
            $Console.ClearCurrentLine()
            
            $itemIndex = $viewportStart + $i
            if ($itemIndex -lt $items.Count) {
                $item = $items[$itemIndex]
                $isSelected = ($itemIndex -eq $selectedOption)
                $prefix = if ($isSelected) { ">" } else { " " }
                $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                
                if ($item.Id -eq "BACK_BUTTON") {
                     $Console.WriteColored("  $prefix $( $item.Name )", $color)
                }
                else {
                    $Console.WriteColored("  $prefix $( $item.Name): ", $color)
                    
                    if ($item.Id -eq "selectedBackground") {
                        # Special handling for background preview
                        $bgVal = $item.CurrentValue
                        $bgDisplay = if ($bgVal -eq 'None') { & $GetLoc "Color.None" "No background" } else { & $GetLoc "Color.$bgVal" $bgVal }
                        
                        $fgColor = if ($bgVal -ne 'None' -and ($bgVal -as [System.ConsoleColor])) { $bgVal } else { $color }
                        $Console.WriteColored($bgDisplay, $fgColor)
                    }
                    else {
                        $Console.WriteColored($item.CurrentValue, $color)
                    }
                }
            }
        }
    }

    hidden [void] RenderFooter([ConsoleHelper]$Console, [string]$msg, [int]$timeout, [int]$footerStart) {
        # Feedback / Status Line
        $Console.SetCursorPosition(0, $footerStart)
        $Console.ClearCurrentLine()
        
        # 1. Separator Line
        $sep = "=" * [Constants]::UIWidth
        $Console.WriteColored($sep, [Constants]::ColorSeparator)
        
        # 2. Message / Help
        $Console.SetCursorPosition(0, $footerStart + 1)
        $Console.ClearCurrentLine()
        
        if ($msg -ne "" -and $timeout -gt 0) {
            $Console.WriteColored("  $msg", [ConsoleColor]::Green)
        } else {
            # Help Text (User requested format)
            $Console.WriteColored("  Use Arrows to navigate | Enter to change/select | Q/Left to go back", [Constants]::ColorHint)
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
        elseif ($item.Id -eq "aliasPosition") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.Value.After" "After Name"); Value = "After" },
                 @{ DisplayText = (& $GetLoc "Pref.Value.Before" "Before Name"); Value = "Before" }
             )
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectAliasPos" "Select Alias Position"), $opts, $preferences.display.aliasPosition, "Cancel")
             if ($newVal) {
                 $PrefsService.SetPreference("display", "aliasPosition", $newVal)
                 $msg = (& $GetLoc "Msg.AliasPosUpdated" "Alias position updated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.Id -eq "aliasSeparator") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.Value.SepHyphen" "Hyphen ( - )"); Value = " - " },
                 @{ DisplayText = (& $GetLoc "Pref.Value.SepColon" "Colon ( : )"); Value = " : " },
                 @{ DisplayText = (& $GetLoc "Pref.Value.SepPipe" "Pipe ( | )"); Value = " | " },
                 @{ DisplayText = (& $GetLoc "Pref.Value.None" "None"); Value = "None" }
             )
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectAliasSep" "Select Alias Separator"), $opts, $preferences.display.aliasSeparator, "Cancel")
             if ($newVal) {
                 $PrefsService.SetPreference("display", "aliasSeparator", $newVal)
                 $msg = (& $GetLoc "Msg.AliasSepUpdated" "Alias separator updated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.Id -eq "aliasWrapper") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.Value.None" "None"); Value = "None" },
                 @{ DisplayText = (& $GetLoc "Pref.Value.WrapParens" "Parentheses (alias)"); Value = "Parens" },
                 @{ DisplayText = (& $GetLoc "Pref.Value.WrapBrackets" "Brackets [alias]"); Value = "Brackets" },
                 @{ DisplayText = (& $GetLoc "Pref.Value.WrapBraces" "Braces {alias]"); Value = "Braces" }
             )
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectAliasWrap" "Select Alias Style"), $opts, $preferences.display.aliasWrapper, "Cancel")
             if ($newVal) {
                 $PrefsService.SetPreference("display", "aliasWrapper", $newVal)
                 $msg = (& $GetLoc "Msg.AliasWrapUpdated" "Alias style updated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.Id -eq "autoLoadGit") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.None" "None"); Value = "None" },
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.Favorites" "Favorites"); Value = "Favorites" },
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.All" "All Repositories"); Value = "All" }
             )
             $newVal = $OptionSelector.ShowSelection((& $GetLoc "Pref.AutoLoadGit"), $opts, $preferences.git.autoLoadGitStatusMode, "Cancel")
             if ($null -ne $newVal) {
                 $PrefsService.SetPreference("git", "autoLoadGitStatusMode", $newVal)
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
             
             $statusKey = if ($newVal) { "Pref.Value.Show" } else { "Pref.Value.Hide" }
             $statusText = & $GetLoc $statusKey "???"
             
             # Use DisplayText if available to be localized, else section key
             $displayName = if ($item.DisplayText) { $item.DisplayText } else { $sec }
             
             $msg = (& $GetLoc "Msg.SectionToggled") -f $displayName, $statusText
             $updated = $true
             $timeout = 1
        }

        return [PSCustomObject]@{ Updated = $updated; Message = $msg; Timeout = $timeout }
    }
}
