class PreferencesMenuController {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [UIRenderer] $Renderer
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [RepositoryManager] $RepoManager

    PreferencesMenuController([object]$context) {
        $this.Console = $context.Console
        $this.PreferencesService = $context.PreferencesService
        $this.Renderer = $context.Renderer
        $this.OptionSelector = $context.OptionSelector
        $this.LocalizationService = $context.LocalizationService
        $this.RepoManager = $context.RepoManager
    }

    [bool] Show() {
        # Define localization helper block
        $GetLoc = { param($key, $def) if ($this.LocalizationService) { return $this.LocalizationService.Get($key) } return $def }

        $preferences = $this.PreferencesService.LoadPreferences()
        $selectedOption = 0
        $running = $true
        $confirmationMessage = ""
        $confirmationTimeout = 0
        
        try {
            $this.Console.HideCursor()
            $fullRedrawNeeded = $true
            # Save cursor position to avoid full screen clearing
            $listStartTop = 0
            
            # Viewport State
            $viewportStart = 0
            
            while ($running) {
                try {
                    # 1. Render Layer
                    if ($fullRedrawNeeded) {
                        $this.Console.ClearScreen()
                        if ($this.Renderer.ShouldShowHeaders()) {
                            $this.Renderer.RenderHeader((& $GetLoc "Pref.Title" "USER PREFERENCES"))
                            Write-Host ""
                        }
                        $listStartTop = $this.Console.GetCursorTop()
                        $fullRedrawNeeded = $false
                    }
                    
                    $this.Console.SetCursorPosition(0, $listStartTop)

                    # 2. Data Layer (Construct Menu Model)
                    $preferenceItems = $this.GetPreferenceItems($preferences, $GetLoc)
                    # Add "Back" as a pseudo-item for consistent navigation
                    $backItem = @{ Id = "BACK_BUTTON"; Name = (& $GetLoc "Pref.Back" "Back to main menu"); CurrentValue = ""; IsAction = $true }
                    $allItems = $preferenceItems + $backItem
                    
                    # Dynamic Page Size Calculation
                    # Header lines (approx 3) + Footer lines (2: Separator + Text) 
                    # Safety margin 1
                    $reserved = $listStartTop + 3 
                    $reservedFooter = 2 # Separator + Message
                    
                    $winHeight = $this.Console.GetWindowHeight() 
                    $maxPageSize = $winHeight - ($reserved + $reservedFooter)
                    if ($maxPageSize -lt 5) { $maxPageSize = 5 } # Min size
                    
                    $pageSize = $maxPageSize
                    
                    # 3. View Layer (Draw Menu)
                    $this.RenderMenu($allItems, $selectedOption, $listStartTop, $viewportStart, $pageSize, $GetLoc)
                    
                    # 4. Feedback / Footer Layer
                    # Footer is always at Start + PageSize
                    $footerLine = $listStartTop + $pageSize
                    $this.RenderFooter($confirmationMessage, $confirmationTimeout, $footerLine, $GetLoc)
                    
                    if ($confirmationTimeout -gt 0) { $confirmationTimeout-- } else { $confirmationMessage = "" }
                    
                    # 5. Input Layer
                    $key = $this.Console.ReadKey()
                    
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

                        ([Constants]::KEY_HOME) {
                            $selectedOption = 0
                            $viewportStart = 0
                        }

                        ([Constants]::KEY_END) {
                            $selectedOption = $allItems.Count - 1
                            if ($selectedOption -ge $pageSize) {
                                $viewportStart = $selectedOption - $pageSize + 1
                            } else {
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
                                $result = $this.HandleSelection($selectedItem, $preferences, $GetLoc)
                                
                                # Always redraw after interaction because OptionSelector dirties the screen
                                $fullRedrawNeeded = $true
                                $viewportStart = 0 # Reset view on redraw usually safer
                                
                                if ($result.Updated) {
                                    $preferences = $this.PreferencesService.LoadPreferences()
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
                    $this.Console.ClearScreen()
                    Write-Host "ERROR IN PREFERENCES MENU:" -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Yellow
                    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
                    Write-Host "Press any key to exit..."
                    $this.Console.ReadKey() | Out-Null
                }
            }
        }
        finally {
            $this.Console.ShowCursor()
        }
        
        return $true
    }

    # Region: Helper Methods
    
    hidden [array] GetPreferenceItems($preferences, $GetLoc) {
        $items = @()

        # 0: Language
        $currentLang = $this.LocalizationService.GetCurrentLanguage()
        $langName = & $GetLoc "Lang.$currentLang" $currentLang
        $items += @{ Id = "language"; Name = (& $GetLoc "Pref.Language" "Language"); CurrentValue = $langName }

        # 0.5: Show Headers
        $headersVal = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
        $headerDisplay = if ($headersVal) { (& $GetLoc "Pref.Value.Show" "Show") } else { (& $GetLoc "Pref.Value.Hide" "Hide") }
        $items += @{ Id = "showHeaders"; Name = (& $GetLoc "Pref.ShowHeaders" "Show Headers"); CurrentValue = $headerDisplay }

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
        
        # 5: Hidden Repos Visibility (REMOVED as per user request - always manual via V)
        # $hiddenDefault = ...
        # $items += @{ Id = "hiddenDefaultVisibility"; ... }
        
        # 5.1: Manage Hidden List
        $hiddenCount = if ($preferences.hidden.hiddenRepos) { $preferences.hidden.hiddenRepos.Count } else { 0 }
        $items += @{ Id = "manageHidden"; Name = (& $GetLoc "Pref.ManageHidden"); CurrentValue = "($hiddenCount)"; IsAction = $true }

        # 6: Menu Mode
        $menuModeDisplay = if ($preferences.display.menuMode) { $preferences.display.menuMode } else { "Full" }
        $items += @{ Id = "menuMode"; Name = (& $GetLoc "Pref.MenuMode" "Menu Display"); CurrentValue = $menuModeDisplay }

        # 6..N: Custom Menu Sections
        if ($preferences.display.menuMode -eq 'Custom' -and $preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                $sections = $preferences.display.menuSections
                $sectionKeys = @("navigation", "alias", "modules", "repository", "git", "tools")
                $sectionLabels = @{
                "navigation" = (& $GetLoc "UI.Group.Nav" "Navigation");
                "alias"      = (& $GetLoc "Pref.Group.Alias" "Alias");
                "modules"    = (& $GetLoc "UI.Group.Modules" "Modules");
                "repository" = (& $GetLoc "UI.Group.Repo" "Repository");
                "git"        = (& $GetLoc "Pref.Group.Git" "Git Status");
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


    hidden [void] RenderMenu([array]$items, [int]$selectedOption, [int]$startTop, [int]$viewportStart, [int]$pageSize, $GetLoc) {
        for ($i = 0; $i -lt $pageSize; $i++) {
            $this.Console.SetCursorPosition(0, $startTop + $i)
            $this.Console.ClearCurrentLine()
            
            $itemIndex = $viewportStart + $i
            if ($itemIndex -lt $items.Count) {
                $item = $items[$itemIndex]
                $isSelected = ($itemIndex -eq $selectedOption)
                $prefix = if ($isSelected) { ">" } else { " " }
                $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                
                if ($item.Id -eq "BACK_BUTTON") {
                     $this.Console.WriteColored("  $prefix $( $item.Name )", $color)
                }
                else {
                    $this.Console.WriteColored("  $prefix $( $item.Name): ", $color)
                    
                    if ($item.Id -eq "selectedBackground") {
                        # Special handling for background preview
                        $bgVal = $item.CurrentValue
                        $bgDisplay = if ($bgVal -eq 'None') { & $GetLoc "Color.None" "No background" } else { & $GetLoc "Color.$bgVal" $bgVal }
                        
                        $fgColor = if ($bgVal -ne 'None' -and ($bgVal -as [System.ConsoleColor])) { $bgVal } else { $color }
                        $this.Console.WriteColored($bgDisplay, $fgColor)
                    }
                    else {
                        $this.Console.WriteColored($item.CurrentValue, $color)
                    }
                }
            }
        }
    }

    hidden [void] RenderFooter([string]$msg, [int]$timeout, [int]$footerStart, $GetLoc) {
        # Feedback / Status Line
        $this.Console.SetCursorPosition(0, $footerStart)
        $this.Console.ClearCurrentLine()
        
        # 1. Separator Line
        $sep = "=" * [Constants]::UIWidth
        $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
        
        # 2. Message / Help
        $this.Console.SetCursorPosition(0, $footerStart + 1)
        $this.Console.ClearCurrentLine()
        
        if ($msg -ne "" -and $timeout -gt 0) {
            $this.Console.WriteColored("  $msg", [ConsoleColor]::Green)
        } else {
            # Help Text (User requested format)
            $hint = & $GetLoc "Pref.Hint" "Use Arrows to navigate | Enter to change/select | Q/Left to go back"
            $this.Console.WriteColored("  $hint", [Constants]::ColorHint)
        }
    }

    hidden [PSCustomObject] HandleSelection($item, $preferences, $GetLoc) {
        $msg = ""
        $timeout = 0
        $updated = $false
        
        if ($item.Id -eq "language") {
            $langs = $this.LocalizationService.GetAvailableLanguages()
            $opts = @()
            foreach ($l in $langs) { 
                $d = & $GetLoc "Lang.$l" $l
                $opts += @{ DisplayText = "$d ($l)"; Value = $l } 
            }
            
            $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectLanguage"), $opts, $this.LocalizationService.GetCurrentLanguage(), "Cancel")
            if ($newVal) {
                $this.LocalizationService.SetLanguage($newVal)
                $this.PreferencesService.SetPreference("general", "language", $newVal)
                $msg = (& $GetLoc "Msg.LanguageChanged" "Language changed to {0}") -f $newVal
                $updated = $true
                $timeout = 5
            }
        }
        elseif ($item.Id -eq "showHeaders") {
            $current = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
            $newVal = -not $current
            $this.PreferencesService.SetPreference("display", "showHeaders", $newVal)
            $msg = (& $GetLoc "Msg.HeaderPrefUpdated" "Header visibility updated")
            $updated = $true
            $timeout = 2
        }
        elseif ($item.Id -eq "favoritesOnTop") {
            $opts = @( @{ DisplayText = (& $GetLoc "Pref.Value.Top"); Value = $true }, @{ DisplayText = (& $GetLoc "Pref.Value.Original"); Value = $false } )
            $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Pref.FavoritesPos"), $opts, $preferences.display.favoritesOnTop, "Cancel")
            if ($null -ne $newVal) {
                 $this.PreferencesService.SetPreference("display", "favoritesOnTop", $newVal)
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
            $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Pref.SelectedBg"), $opts, $preferences.display.selectedBackground, "Cancel")
            if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "selectedBackground", $newVal)
                 $msg = (& $GetLoc "Msg.BackgroundUpdated")
                 $updated = $true
                 $timeout = 2
            }
        }
        elseif ($item.Id -eq "selectedDelimiter") {
             $opts = @()
             foreach ($d in [Constants]::AvailableDelimiters) { $opts += @{ DisplayText = $d.Name; Value = $d.Name } }
             $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Pref.SelectedDelim"), $opts, $preferences.display.selectedDelimiter, "Cancel")
             if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "selectedDelimiter", $newVal)
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
             $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectAliasPos" "Select Alias Position"), $opts, $preferences.display.aliasPosition, "Cancel")
             if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "aliasPosition", $newVal)
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
             $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectAliasSep" "Select Alias Separator"), $opts, $preferences.display.aliasSeparator, "Cancel")
             if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "aliasSeparator", $newVal)
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
             $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Prompt.SelectAliasWrap" "Select Alias Style"), $opts, $preferences.display.aliasWrapper, "Cancel")
             if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "aliasWrapper", $newVal)
                 $msg = (& $GetLoc "Msg.AliasWrapUpdated" "Alias style updated")
                 $updated = $true
                 $timeout = 2
             }
        }
        # hiddenDefaultVisibility REMOVED
        elseif ($item.Id -eq "manageHidden") {
             $this.ManageHiddenRepos($preferences, $GetLoc)
             $updated = $true
             $msg = "" # Message handled inside manager or just refresh
        }
        elseif ($item.Id -eq "autoLoadGit") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.None" "None"); Value = "None" },
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.Favorites" "Favorites"); Value = "Favorites" },
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.All" "All Repositories"); Value = "All" }
             )
             $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Pref.AutoLoadGit"), $opts, $preferences.git.autoLoadGitStatusMode, "Cancel")
             if ($null -ne $newVal) {
                 $this.PreferencesService.SetPreference("git", "autoLoadGitStatusMode", $newVal)
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
             $newVal = $this.OptionSelector.ShowSelection((& $GetLoc "Pref.MenuMode"), $opts, $preferences.display.menuMode, "Cancel")
             if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "menuMode", $newVal)
                 $msg = (& $GetLoc "Msg.MenuModeUpdated")
                 $updated = $true
                 $timeout = 2
             }
        }
        elseif ($item.IsSectionToggle) {
             $sec = $item.SectionKey
             $newVal = -not $item.RawValue
             $preferences.display.menuSections.$sec = $newVal
             $this.PreferencesService.SavePreferences($preferences)
             
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

    # Manage hidden repositories
    [void] ManageHiddenRepos([PSCustomObject]$preferences, [scriptblock]$GetLoc) {
        $hiddenService = $this.RepoManager.HiddenReposService
        if ($null -eq $hiddenService) { return }
        
        $running = $true
        
        while ($running) {
            $hiddenList = $hiddenService.GetHiddenList()
            
            if ($hiddenList.Count -eq 0) {
                $this.Console.WriteLineColored("  " + (& $GetLoc "Msg.NoHiddenRepos"), [Constants]::ColorInfo)
                Start-Sleep -Seconds 1
                return
            }
            
            # Create friendly options (Name as DisplayText, Path as Value)
            $options = @()
            foreach ($path in $hiddenList) {
                $name = Split-Path -Path $path -Leaf
                $options += @{ DisplayText = $name; Value = $path }
            }
            
            $title = & $GetLoc "Menu.ManageHidden"
            $description = "Select a repository to UNHIDE (restore to list)"
            $cancelText = & $GetLoc "Cmd.Back"
            
            # Callback to render full path detail
            $capturedConsole = $this.Console # Capture for closure
            $onSelectionChanged = {
                param($selectedOption)
                $path = $selectedOption.Value
                $capturedConsole.WriteLineColored("    $path", [Constants]::ColorHint)
            }
            
            $selector = [OptionSelector]::new($this.Console, $this.Renderer)
            # Pass null for currentValue (no pre-selection)
            # Pass onSelectionChanged as last argument
            $selectedPath = $selector.ShowSelection($title, $options, $null, $cancelText, $false, $description, [Constants]::ColorInfo, $true, $onSelectionChanged)
            
            if ($null -eq $selectedPath) {
                $running = $false
            } else {
                # Unhide selected
                $hiddenService.RemoveFromHidden($selectedPath)
                $this.Console.WriteLineColored("  Unhided: $selectedPath", [Constants]::ColorSuccess)
                Start-Sleep -Milliseconds 800
                
                # Loop continues
            }
        }
    }
}
