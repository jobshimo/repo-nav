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

        # 5.2: Manage Repository Paths
        $pathCount = if ($preferences.repository.paths) { $preferences.repository.paths.Count } else { 0 }
        $items += @{ Id = "managePaths"; Name = (& $GetLoc "Pref.ManagePaths" "Manage Repository Paths"); CurrentValue = "($pathCount)"; IsAction = $true }

        # 5.3: Path Display Mode
        $pathModeDisplay = if ($preferences.display.pathDisplayMode) { $preferences.display.pathDisplayMode } else { "Path" }
        $items += @{ Id = "pathDisplay"; Name = (& $GetLoc "Pref.PathDisplay" "Path Display Mode"); CurrentValue = $pathModeDisplay }

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

        # ═══════════════════════════════════════════════════════════════════════════
        # DEV ONLY: Build Bundle option (only visible when running from source)
        # ═══════════════════════════════════════════════════════════════════════════
        $devToolsPath = Join-Path ([Constants]::ScriptRoot) "src\Dev\DevToolsCommand.ps1"
        if (Test-Path $devToolsPath) {
            $items += @{ Id = "buildBundle"; Name = "--- DEV: Build Bundle ---"; CurrentValue = ""; IsAction = $true; IsDev = $true }
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
            
            $config = [SelectionOptions]::new()
            $config.Title = (& $GetLoc "Prompt.SelectLanguage")
            $config.Options = $opts
            $config.CurrentValue = $this.LocalizationService.GetCurrentLanguage()
            $newVal = $this.OptionSelector.Show($config)
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
            $config = [SelectionOptions]::new()
            $config.Title = (& $GetLoc "Pref.FavoritesPos")
            $config.Options = $opts
            $config.CurrentValue = $preferences.display.favoritesOnTop
            $newVal = $this.OptionSelector.Show($config)
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
            $config = [SelectionOptions]::new()
            $config.Title = (& $GetLoc "Pref.SelectedBg")
            $config.Options = $opts
            $config.CurrentValue = $preferences.display.selectedBackground
            $newVal = $this.OptionSelector.Show($config)
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
             $config = [SelectionOptions]::new()
             $config.Title = (& $GetLoc "Pref.SelectedDelim")
             $config.Options = $opts
             $config.CurrentValue = $preferences.display.selectedDelimiter
             $newVal = $this.OptionSelector.Show($config)
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
             $config = [SelectionOptions]::new()
             $config.Title = (& $GetLoc "Prompt.SelectAliasPos" "Select Alias Position")
             $config.Options = $opts
             $config.CurrentValue = $preferences.display.aliasPosition
             $newVal = $this.OptionSelector.Show($config)
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
             $config = [SelectionOptions]::new()
             $config.Title = (& $GetLoc "Prompt.SelectAliasSep" "Select Alias Separator")
             $config.Options = $opts
             $config.CurrentValue = $preferences.display.aliasSeparator
             $newVal = $this.OptionSelector.Show($config)
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
             $config = [SelectionOptions]::new()
             $config.Title = (& $GetLoc "Prompt.SelectAliasWrap" "Select Alias Style")
             $config.Options = $opts
             $config.CurrentValue = $preferences.display.aliasWrapper
             $newVal = $this.OptionSelector.Show($config)
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
        elseif ($item.Id -eq "managePaths") {
             $this.ManageRepositoryPaths($preferences, $GetLoc)
             $updated = $true
             $msg = ""
        }
        elseif ($item.Id -eq "pathDisplay") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.PathDisplay.Path"); Value = "Path" },
                 @{ DisplayText = (& $GetLoc "Pref.PathDisplay.Alias"); Value = "Alias" },
                 @{ DisplayText = (& $GetLoc "Pref.PathDisplay.Both"); Value = "Both" }
             )
             $current = if ($preferences.display.pathDisplayMode) { $preferences.display.pathDisplayMode } else { "Path" }
             $newVal = $this.ShowOptionSelector((& $GetLoc "Pref.PathDisplay"), $opts, $current)
             
             if ($newVal) {
                 $this.PreferencesService.SetPreference("display", "pathDisplayMode", $newVal)
                 $updated = $true
                 $msg = "Path display mode updated"
             }
        }
        elseif ($item.Id -eq "autoLoadGit") {
             $opts = @(
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.None" "None"); Value = "None" },
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.Favorites" "Favorites"); Value = "Favorites" },
                 @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.All" "All Repositories"); Value = "All" }
             )
             $config = [SelectionOptions]::new()
             $config.Title = (& $GetLoc "Pref.AutoLoadGit")
             $config.Options = $opts
             $config.CurrentValue = $preferences.git.autoLoadGitStatusMode
             $newVal = $this.OptionSelector.Show($config)
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
             $config = [SelectionOptions]::new()
             $config.Title = (& $GetLoc "Pref.MenuMode")
             $config.Options = $opts
             $config.CurrentValue = $preferences.display.menuMode
             $newVal = $this.OptionSelector.Show($config)
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
        # ═══════════════════════════════════════════════════════════════════════════
        # DEV ONLY: Build Bundle (dynamically loaded, not in bundle)
        # ═══════════════════════════════════════════════════════════════════════════
        elseif ($item.Id -eq "buildBundle") {
            $devToolsPath = Join-Path ([Constants]::ScriptRoot) "src\Dev\DevToolsCommand.ps1"
            if (Test-Path $devToolsPath) {
                . $devToolsPath
                # Use dynamic invocation to avoid type resolution at parse time
                $consoleRef = $this.Console
                Invoke-Expression '[DevToolsCommand]::BuildBundle($consoleRef)'
            }
            $updated = $true
        }

        return [PSCustomObject]@{ Updated = $updated; Message = $msg; Timeout = $timeout }
    }

    # Manage hidden repositories
    [void] ManageHiddenRepos([PSCustomObject]$preferences, [scriptblock]$GetLoc) {
        $hiddenService = $this.RepoManager.HiddenReposService
        if ($null -eq $hiddenService) { return }
        
        $running = $true
        $statusMessage = $null
        
        while ($running) {
            $hiddenList = $hiddenService.GetHiddenList()
            
            if ($hiddenList.Count -eq 0) {
                $this.Console.WriteLineColored("  " + (& $GetLoc "Msg.NoHiddenRepos"), [Constants]::ColorInfo)
                Start-Sleep -Seconds 1
                return
            }
            
            # Create rich options by hydrating temporary RepositoryModels
            $options = @()
            $aliases = $this.RepoManager.AliasManager.GetAllAliases()
            
            foreach ($path in $hiddenList) {
                if (Test-Path $path) {
                    $item = Get-Item $path
                    $repo = [RepositoryModel]::new($item)
                    
                    # Hydrate basic info needed for display
                    if ($this.RepoManager.GitService.IsContainerDirectory($path)) {
                        $count = $this.RepoManager.GitService.CountContainedRepositories($path)
                        $repo.MarkAsContainer($count)
                    }
                    
                    if ($aliases.ContainsKey($path)) {
                        $repo.SetAlias($aliases[$path])
                    }
                    
                    # Favorites might be tricky if based on Name vs FullPath, 
                    # but FavoriteService now uses FullPath, so update model
                    $this.RepoManager.FavoriteService.UpdateRepositoryModel($repo)

                    $options += @{ Value = $repo; DisplayText = $repo.Name }
                } else {
                    # Path not found (maybe deleted outside), show as text
                    $options += @{ Value = $path; DisplayText = "$path (Missing)" }
                }
            }
            
            $title = & $GetLoc "Menu.ManageHidden"
            $description = "Select a repository to UNHIDE (restore to list)"
            if ($null -ne $statusMessage) {
                $description += "`n`n$statusMessage"
            }
            
            $cancelText = & $GetLoc "Cmd.Back"
            
            # ... (Callback definitions) ...
            $capturedConsole = $this.Console # Capture for closure
            $onSelectionChanged = {
                param($selectedOption)
                $val = $selectedOption.Value
                if ($val -is [RepositoryModel]) {
                    $capturedConsole.WriteLineColored("    $($val.FullPath)", [Constants]::ColorHint)
                } else {
                    $capturedConsole.WriteLineColored("    $val", [Constants]::ColorHint)
                }
            }

            # Callback for rich item rendering
            # $option is the hashtable from $options array
            $onRenderItem = {
                param($option, $isSelected, $prefix)
                
                $val = $option.Value
                
                if ($val -is [RepositoryModel]) {
                   $repo = $val
                   
                   # Build display string similar to UIRenderer
                   $icon = if ($repo.IsContainer) { "[+]" } elseif ($repo.IsFavorite) { "[*]" } else { "   " }
                   $text = $repo.Name
                   
                   # Alias - Robust check
                   $aliasStr = ""
                   if (-not [string]::IsNullOrEmpty($repo.Alias)) {
                       $aliasStr = " ($($repo.Alias))"
                   }
                   
                   # Container count - Robust check
                   $countStr = ""
                   if ($repo.IsContainer) {
                       $countVal = if ($null -ne $repo.ContainerRepoCount) { $repo.ContainerRepoCount } else { 0 }
                       $countStr = " ($countVal)"
                   }
                   
                   # Colors logic
                   $baseColor = [Constants]::ColorRepo
                   
                   if ($repo.IsContainer) { 
                        $baseColor = [Constants]::ColorContainer 
                   }
                   
                   if ($isSelected) { 
                        $baseColor = [Constants]::ColorSelected 
                   } elseif ($repo.IsFavorite) {
                        # Only show favorite color if not selected (and not container override? usually favorite overrides repo color)
                        $baseColor = [Constants]::ColorFavorite
                   }
                   
                   # Safety for null color
                   if ($null -eq $baseColor) { $baseColor = [Constants]::ColorRepo }

                   # Construct line
                   $capturedConsole.ClearLine()
                   $line = "  $prefix $icon $text$aliasStr$countStr"
                   
                   try {
                       $capturedConsole.WriteLineColored($line, $baseColor)
                   } catch {
                       # Fallback if color is somehow invalid
                       $capturedConsole.WriteLineColored($line, [ConsoleColor]::Gray)
                   }
                   
                } else {
                   # Fallback for missing items or strings
                   $capturedConsole.ClearLine()
                   $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                   # Ensure color is valid
                   if ($null -eq $color) { $color = [ConsoleColor]::Gray }
                   
                   $displayText = if ($option.DisplayText) { $option.DisplayText } else { $option.Value }
                   $capturedConsole.WriteLineColored("  $prefix $displayText", $color)
                }
            }
            
            $selector = [OptionSelector]::new($this.Console, $this.Renderer)
            # Pass onRenderItem as last argument
            $config = [SelectionOptions]::new()
            $config.Title = $title
            $config.Options = $options
            $config.CancelText = $cancelText
            $config.ShowCurrentMarker = $false
            $config.Description = $description
            $config.DescriptionColor = [Constants]::ColorInfo
            $config.OnSelectionChanged = $onSelectionChanged
            $config.OnRenderItem = $onRenderItem
            $selectedResult = $selector.Show($config)
            
            $selectedPath = if ($null -ne $selectedResult) { 
                if ($selectedResult -is [RepositoryModel]) { $selectedResult.FullPath } else { $selectedResult }
            } else { $null }
            
            if ($null -eq $selectedPath) {
                $running = $false
            } else {
                # Unhide selected
                $hiddenService.RemoveFromHidden($selectedPath)
                $name = Split-Path -Path $selectedPath -Leaf
                $statusMessage = "  [Success] Unhided: $name"
                
                # Loop continues immediately
            }
        }
    }

    # Manage repository paths
    [void] ManageRepositoryPaths([PSCustomObject]$preferences, [scriptblock]$GetLoc) {
        $running = $true
        $statusMessage = $null
        
        while ($running) {
            $paths = if ($preferences.repository.paths) { $preferences.repository.paths } else { @() }
            
            $options = @()
            $options += @{ Value = "ADD_NEW"; DisplayText = "[+] " + (& $GetLoc "Cmd.AddPath" "Add New Path...") }
            
            $pathAliases = if ($preferences.repository.pathAliases) { $preferences.repository.pathAliases } else { ([PSCustomObject]@{}) }
            
            foreach ($p in $paths) {
                # Determine if valid
                $exists = Test-Path $p
                $display = "$p"
                
                # Check for alias
                if ($pathAliases.$p) { $display += " [$($pathAliases.$p)]" }
                
                if (-not $exists) { $display += " (Missing)" }
                
                $options += @{ Value = $p; DisplayText = $display }
            }
            
            $title = & $GetLoc "Menu.ManagePaths" "Manage Repository Paths"
            $description = "Select a path to Manage it (Alias/Remove), or Add New."
            
            if ($null -ne $statusMessage) {
                $description += "`n`n$statusMessage"
            }
            
            $config = [SelectionOptions]::new()
            $config.Title = $title
            $config.Options = $options
            $config.CancelText = (& $GetLoc "Cmd.Back")
            $config.Description = $description
            $config.DescriptionColor = [Constants]::ColorInfo
            $config.ShowCurrentMarker = $false
            
            $selector = [OptionSelector]::new($this.Console, $this.Renderer)
            $selected = $selector.Show($config)
            
            if ($null -eq $selected) {
                $running = $false
            }
            elseif ($selected -eq "ADD_NEW") {
                # Add new path
                $this.Console.ClearScreen()
                $this.Renderer.RenderHeader("ADD REPOSITORY PATH")
                Write-Host ""
                Write-Host "  Current Location: $((Get-Location).Path)" -ForegroundColor Gray
                Write-Host "  Enter absolute path:" -ForegroundColor Yellow
                
                $this.Console.ShowCursor()
                $inputPath = Read-Host "  > "
                $this.Console.HideCursor()
                
                if (-not [string]::IsNullOrWhiteSpace($inputPath)) {
                    # Normalize path
                    try {
                        if (Test-Path $inputPath) {
                            $fullPath = (Resolve-Path $inputPath).Path
                            
                            # Add to preferences if not exists
                            $currentPaths = if ($preferences.repository.paths) { [array]$preferences.repository.paths } else { @() }
                            
                            if ($currentPaths -contains $fullPath) {
                                $statusMessage = "[Warning] Path already exists."
                            } else {
                                $currentPaths += $fullPath
                                $this.PreferencesService.SetPreference("repository", "paths", $currentPaths)
                                $statusMessage = "[Success] Added: $fullPath"
                                # Reload local ref
                                $preferences = $this.PreferencesService.LoadPreferences()
                            }
                        } else {
                            $statusMessage = "[Error] Path does not exist."
                        }
                    } catch {
                         $statusMessage = "[Error] Invalid path: $_"
                    }
                }
            }
            else {
                # Manage selected path
                $selectedPath = $selected
                
                $mOpts = @(
                    @{ DisplayText = "Set Alias"; Value = "ALIAS" },
                    @{ DisplayText = "Remove Path"; Value = "REMOVE" }
                )
                
                $actConfig = [SelectionOptions]::new()
                $actConfig.Title = "MANAGE: $selectedPath"
                $actConfig.Options = $mOpts
                $actConfig.CancelText = "Back"
                
                $action = $selector.Show($actConfig)
                
                if ($action -eq "REMOVE") {
                     $currentPaths = [array]$preferences.repository.paths
                     $newPaths = $currentPaths | Where-Object { $_ -ne $selectedPath }
                     
                     $this.PreferencesService.SetPreference("repository", "paths", $newPaths)
                     
                     # Also remove alias if exists
                     if ($preferences.repository.pathAliases.$selectedPath) {
                         $currentAliases = $preferences.repository.pathAliases
                         $currentAliases.PSObject.Properties.Remove($selectedPath)
                         $this.PreferencesService.SetPreference("repository", "pathAliases", $currentAliases)
                     }
                     
                     $statusMessage = "[Success] Removed: $selectedPath"
                     $preferences = $this.PreferencesService.LoadPreferences()
                }
                elseif ($action -eq "ALIAS") {
                     $this.Console.ClearScreen()
                     $this.Renderer.RenderHeader("SET ALIAS")
                     Write-Host ""
                     Write-Host "  Path: $selectedPath" -ForegroundColor Gray
                     Write-Host "  Enter alias (leave empty to remove):" -ForegroundColor Yellow
                     
                     $this.Console.ShowCursor()
                     $newAlias = Read-Host "  > "
                     $this.Console.HideCursor()
                     
                     $currentAliases = if ($preferences.repository.pathAliases) { $preferences.repository.pathAliases } else { ([PSCustomObject]@{}) }
                     
                     if ([string]::IsNullOrWhiteSpace($newAlias)) {
                         if ($currentAliases.PSObject.Properties.Name -contains $selectedPath) {
                             $currentAliases.PSObject.Properties.Remove($selectedPath)
                             $statusMessage = "[Success] Alias removed."
                         }
                     } else {
                         if ($currentAliases.PSObject.Properties.Name -contains $selectedPath) {
                             $currentAliases.$selectedPath = $newAlias
                         } else {
                             $currentAliases | Add-Member -NotePropertyName $selectedPath -NotePropertyValue $newAlias -Force
                         }
                         $statusMessage = "[Success] Alias set to '$newAlias'."
                     }
                     
                     $this.PreferencesService.SetPreference("repository", "pathAliases", $currentAliases)
                     $preferences = $this.PreferencesService.LoadPreferences()
                }
            }
        }
    }
}
