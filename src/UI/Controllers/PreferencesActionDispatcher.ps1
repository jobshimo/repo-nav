<#
.SYNOPSIS
    PreferencesActionDispatcher - Handles all preference actions.
    
.DESCRIPTION
    Extracted from PreferencesMenuController following SRP:
    - This class ONLY handles action execution
    - PreferencesMenuController handles navigation and orchestration
#>

class PreferencesActionDispatcher {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [IUIRenderer] $Renderer
    [OptionSelector] $OptionSelector
    [LocalizationService] $LocalizationService
    [RepositoryManager] $RepoManager
    [PathManager] $PathManager
    
    PreferencesActionDispatcher([object]$context) {
        $this.Console = $context.Console
        $this.PreferencesService = $context.PreferencesService
        $this.Renderer = $context.Renderer
        $this.OptionSelector = $context.OptionSelector
        $this.LocalizationService = $context.LocalizationService
        $this.RepoManager = $context.RepoManager
        $this.PathManager = $context.PathManager
    }
    
    # Main dispatch method - routes to appropriate handler
    [PSCustomObject] Dispatch([hashtable]$item, [PSCustomObject]$preferences, [scriptblock]$GetLoc) {
        switch ($item.Id) {
            "language" { return $this.HandleLanguage($GetLoc) }
            "showHeaders" { return $this.HandleShowHeaders($preferences, $GetLoc) }
            "favoritesOnTop" { return $this.HandleFavoritesOnTop($preferences, $GetLoc) }
            "selectedBackground" { return $this.HandleSelectedBackground($preferences, $GetLoc) }
            "selectedDelimiter" { return $this.HandleSelectedDelimiter($preferences, $GetLoc) }
            "aliasPosition" { return $this.HandleAliasPosition($preferences, $GetLoc) }
            "aliasSeparator" { return $this.HandleAliasSeparator($preferences, $GetLoc) }
            "aliasWrapper" { return $this.HandleAliasWrapper($preferences, $GetLoc) }
            "manageHidden" { return $this.HandleManageHidden($preferences, $GetLoc) }
            "managePaths" { return $this.HandleManagePaths($preferences, $GetLoc) }
            "pathDisplay" { return $this.HandlePathDisplay($preferences, $GetLoc) }
            "autoLoadGit" { return $this.HandleAutoLoadGit($preferences, $GetLoc) }
            "menuMode" { return $this.HandleMenuMode($preferences, $GetLoc) }
            "buildBundle" { return $this.HandleBuildBundle() }
            default {
                if ($item.IsSectionToggle) {
                    return $this.HandleSectionToggle($item, $preferences, $GetLoc)
                }
                return $this.NoChange()
            }
        }
        return $this.NoChange()
    }

    #region Simple Handlers
    
    hidden [PSCustomObject] HandleLanguage([scriptblock]$GetLoc) {
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
            return $this.Changed((& $GetLoc "Msg.LanguageChanged") -f $newVal, 5)
        }
        return $this.NoChange()
    }
    
    hidden [PSCustomObject] HandleShowHeaders([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $current = if ($prefs.display.PSObject.Properties.Name -contains 'showHeaders') { $prefs.display.showHeaders } else { $true }
        $newVal = -not $current
        $this.PreferencesService.SetPreference("display", "showHeaders", $newVal)
        return $this.Changed((& $GetLoc "Msg.HeaderPrefUpdated"), 2)
    }
    
    hidden [PSCustomObject] HandleFavoritesOnTop([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @( 
            @{ DisplayText = (& $GetLoc "Pref.Value.Top"); Value = $true }, 
            @{ DisplayText = (& $GetLoc "Pref.Value.Original"); Value = $false } 
        )
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Pref.FavoritesPos")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.favoritesOnTop
        $newVal = $this.OptionSelector.Show($config)
        
        if ($null -ne $newVal) {
            $this.PreferencesService.SetPreference("display", "favoritesOnTop", $newVal)
            return $this.Changed((& $GetLoc "Msg.FavoritesPosUpdated"), 2)
        }
        return $this.NoChange()
    }
    
    hidden [PSCustomObject] HandleSelectedBackground([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @()
        foreach ($bg in [Constants]::AvailableBackgroundColors) {
            $txt = if ($bg -eq 'None') { & $GetLoc "Color.None" } else { & $GetLoc "Color.$bg" $bg }
            $opts += @{ DisplayText = $txt; Value = $bg }
        }
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Pref.SelectedBg")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.selectedBackground
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "selectedBackground", $newVal)
            return $this.Changed((& $GetLoc "Msg.BackgroundUpdated"), 2)
        }
        return $this.NoChange()
    }
    
    hidden [PSCustomObject] HandleSelectedDelimiter([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @()
        foreach ($d in [Constants]::AvailableDelimiters) { 
            $opts += @{ DisplayText = $d.Name; Value = $d.Name } 
        }
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Pref.SelectedDelim")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.selectedDelimiter
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "selectedDelimiter", $newVal)
            return $this.Changed((& $GetLoc "Msg.DelimiterUpdated"), 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandleAliasPosition([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @(
            @{ DisplayText = (& $GetLoc "Pref.Value.After"); Value = "After" },
            @{ DisplayText = (& $GetLoc "Pref.Value.Before"); Value = "Before" }
        )
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Prompt.SelectAliasPos")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.aliasPosition
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "aliasPosition", $newVal)
            return $this.Changed((& $GetLoc "Msg.AliasPosUpdated"), 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandleAliasSeparator([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @(
            @{ DisplayText = (& $GetLoc "Pref.Value.SepHyphen"); Value = " - " },
            @{ DisplayText = (& $GetLoc "Pref.Value.SepColon"); Value = " : " },
            @{ DisplayText = (& $GetLoc "Pref.Value.SepPipe"); Value = " | " },
            @{ DisplayText = (& $GetLoc "Pref.Value.None"); Value = "None" }
        )
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Prompt.SelectAliasSep")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.aliasSeparator
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "aliasSeparator", $newVal)
            return $this.Changed((& $GetLoc "Msg.AliasSepUpdated"), 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandleAliasWrapper([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @(
            @{ DisplayText = (& $GetLoc "Pref.Value.None"); Value = "None" },
            @{ DisplayText = (& $GetLoc "Pref.Value.WrapParens"); Value = "Parens" },
            @{ DisplayText = (& $GetLoc "Pref.Value.WrapBrackets"); Value = "Brackets" },
            @{ DisplayText = (& $GetLoc "Pref.Value.WrapBraces"); Value = "Braces" }
        )
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Prompt.SelectAliasWrap")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.aliasWrapper
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "aliasWrapper", $newVal)
            return $this.Changed((& $GetLoc "Msg.AliasWrapUpdated"), 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandlePathDisplay([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @(
            @{ DisplayText = (& $GetLoc "Pref.PathDisplay.Path"); Value = "Path" },
            @{ DisplayText = (& $GetLoc "Pref.PathDisplay.Alias"); Value = "Alias" },
            @{ DisplayText = (& $GetLoc "Pref.PathDisplay.Both"); Value = "Both" }
        )
        $current = if ($prefs.display.pathDisplayMode) { $prefs.display.pathDisplayMode } else { "Path" }
        
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Pref.PathDisplay")
        $config.Options = $opts
        $config.CurrentValue = $current
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "pathDisplayMode", $newVal)
            return $this.Changed("Path display mode updated", 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandleAutoLoadGit([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @(
            @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.None"); Value = "None" },
            @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.Favorites"); Value = "Favorites" },
            @{ DisplayText = (& $GetLoc "Pref.AutoLoadGit.All"); Value = "All" }
        )
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Pref.AutoLoadGit")
        $config.Options = $opts
        $config.CurrentValue = $prefs.git.autoLoadGitStatusMode
        $newVal = $this.OptionSelector.Show($config)
        
        if ($null -ne $newVal) {
            $this.PreferencesService.SetPreference("git", "autoLoadGitStatusMode", $newVal)
            return $this.Changed((& $GetLoc "Msg.AutoLoadUpdated"), 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandleMenuMode([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $opts = @(
            @{ DisplayText = (& $GetLoc "Pref.MenuMode.Full"); Value = "Full" },
            @{ DisplayText = (& $GetLoc "Pref.MenuMode.Minimal"); Value = "Minimal" },
            @{ DisplayText = (& $GetLoc "Pref.MenuMode.Custom"); Value = "Custom" },
            @{ DisplayText = (& $GetLoc "Pref.MenuMode.Hidden"); Value = "Hidden" }
        )
        $config = [SelectionOptions]::new()
        $config.Title = (& $GetLoc "Pref.MenuMode")
        $config.Options = $opts
        $config.CurrentValue = $prefs.display.menuMode
        $newVal = $this.OptionSelector.Show($config)
        
        if ($newVal) {
            $this.PreferencesService.SetPreference("display", "menuMode", $newVal)
            return $this.Changed((& $GetLoc "Msg.MenuModeUpdated"), 2)
        }
        return $this.NoChange()
    }

    hidden [PSCustomObject] HandleSectionToggle([hashtable]$item, [PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $sec = $item.SectionKey
        $newVal = -not $item.RawValue
        $prefs.display.menuSections.$sec = $newVal
        $this.PreferencesService.SavePreferences($prefs)
        
        $statusKey = if ($newVal) { "Pref.Value.Show" } else { "Pref.Value.Hide" }
        $statusText = (& $GetLoc $statusKey)
        $displayName = if ($item.DisplayText) { $item.DisplayText } else { $sec }
        
        $msg = (& $GetLoc "Msg.SectionToggled") -f $displayName, $statusText
        return $this.Changed($msg, 1)
    }

    hidden [PSCustomObject] HandleBuildBundle() {
        $devToolsPath = Join-Path ([Constants]::ScriptRoot) "src\Dev\DevToolsCommand.ps1"
        if (Test-Path $devToolsPath) {
            . $devToolsPath
            $consoleRef = $this.Console
            Invoke-Expression '[DevToolsCommand]::BuildBundle($consoleRef)'
        }
        return $this.Changed("", 0)
    }
    #endregion
    
    #region Complex Handlers (sub-menus)
    
    hidden [PSCustomObject] HandleManageHidden([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $this.ShowManageHiddenMenu($prefs, $GetLoc)
        return $this.Changed("", 0)
    }
    
    hidden [PSCustomObject] HandleManagePaths([PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $this.ShowManagePathsMenu($prefs, $GetLoc)
        return $this.Changed("", 0)
    }
    
    # ManageHidden implementation (extracted from original)
    hidden [void] ShowManageHiddenMenu([PSCustomObject]$preferences, [scriptblock]$GetLoc) {
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
            
            $allRepos = $this.RepoManager.GetRepositoriesAcrossAllPaths()
            $options = @()
            
            foreach ($path in $hiddenList) {
                $matchedRepo = $allRepos | Where-Object { $_.FullPath -eq $path } | Select-Object -First 1
                if ($matchedRepo) {
                    $options += @{ DisplayText = $matchedRepo.Name; Value = $matchedRepo }
                } else {
                    $name = Split-Path -Path $path -Leaf
                    $options += @{ DisplayText = "$name (missing)"; Value = $path }
                }
            }
            
            $title = & $GetLoc "Menu.ManageHidden" "Manage Hidden Repositories"
            $cancelText = & $GetLoc "Cmd.Back" "Back"
            
            $config = [SelectionOptions]::new()
            $config.Title = $title
            $config.Options = $options
            $config.CancelText = $cancelText
            
            $selector = [OptionSelector]::new($this.Console, $this.Renderer)
            $selectedResult = $selector.Show($config)
            
            $selectedPath = if ($null -ne $selectedResult) { 
                if ($selectedResult -is [RepositoryModel]) { $selectedResult.FullPath } else { $selectedResult }
            } else { $null }
            
            if ($null -eq $selectedPath) {
                $running = $false
            } else {
                $hiddenService.RemoveFromHidden($selectedPath)
            }
        }
    }
    
    # ManagePaths implementation (extracted and simplified)
    hidden [void] ShowManagePathsMenu([PSCustomObject]$preferences, [scriptblock]$GetLoc) {
        $running = $true
        $statusMessage = $null
        
        while ($running) {
            $prefs = $this.PreferencesService.LoadPreferences()
            $paths = [ArrayHelper]::EnsureArray($prefs.repository.paths)
            
            $options = @()
            $options += @{ Value = "ADD_NEW"; DisplayText = "[+] " + (& $GetLoc "Cmd.AddPath" "Add New Path...") }
            
            $pathAliases = if ($prefs.repository.pathAliases) { $prefs.repository.pathAliases } else { ([PSCustomObject]@{}) }
            
            foreach ($p in $paths) {
                $exists = Test-Path $p
                $display = "$p"
                
                if ($pathAliases.$p) { 
                    $aliasVal = $pathAliases.$p
                    $aliasText = if ($aliasVal -is [string]) { $aliasVal } elseif ($aliasVal.Text) { $aliasVal.Text } else { "" }
                    if ($aliasText) { $display += " [$aliasText]" }
                }
                
                if ($prefs.repository.defaultPath -eq $p) { $display += " (Default)" }
                if (-not $exists) { $display += " (Missing)" }
                
                $options += @{ Value = $p; DisplayText = $display }
            }
            
            $config = [SelectionOptions]::new()
            $config.Title = & $GetLoc "Menu.ManagePaths" "Manage Repository Paths"
            $config.Options = $options
            $config.CancelText = (& $GetLoc "Cmd.Back")
            $config.Description = if ($statusMessage) { $statusMessage } else { "" }
            $config.DescriptionColor = [Constants]::ColorInfo
            
            $selector = [OptionSelector]::new($this.Console, $this.Renderer)
            $selected = $selector.Show($config)
            $statusMessage = $null
            
            if ($null -eq $selected) {
                $running = $false
            }
            elseif ($selected -eq "ADD_NEW") {
                $statusMessage = $this.AddNewPath($GetLoc)
            }
            else {
                $statusMessage = $this.ManageSelectedPath($selected, $prefs, $GetLoc)
            }
        }
    }
    
    hidden [string] AddNewPath([scriptblock]$GetLoc) {
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("ADD REPOSITORY PATH")
        Write-Host ""
        Write-Host "  Current Location: $((Get-Location).Path)" -ForegroundColor Gray
        Write-Host "  Enter absolute path:" -ForegroundColor Yellow
        
        $this.Console.ShowCursor()
        $inputPath = Read-Host "  > "
        $this.Console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($inputPath)) { return $null }
        
        try {
            if (Test-Path $inputPath) {
                $fullPath = (Resolve-Path $inputPath).Path
                if ($this.PathManager.AddPath($fullPath)) {
                    return "[Success] Added: $fullPath"
                } else {
                    return "[Warning] Path already exists or invalid."
                }
            } else {
                return "[Error] Path does not exist."
            }
        } catch {
            return "[Error] Invalid path: $_"
        }
    }
    
    hidden [string] ManageSelectedPath([string]$selectedPath, [PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $mOpts = @(
            @{ DisplayText = "Set Alias"; Value = "ALIAS" },
            @{ DisplayText = "Set as Default"; Value = "SET_DEFAULT" },
            @{ DisplayText = "Remove Path"; Value = "REMOVE" }
        )
        
        $actConfig = [SelectionOptions]::new()
        $actConfig.Title = "MANAGE: $selectedPath"
        $actConfig.Options = $mOpts
        $actConfig.CancelText = "Back"
        
        $selector = [OptionSelector]::new($this.Console, $this.Renderer)
        $action = $selector.Show($actConfig)
        
        switch ($action) {
            "SET_DEFAULT" {
                $this.PathManager.SetCurrentPath($selectedPath)
                return "[Success] Default path set to: $selectedPath"
            }
            "REMOVE" {
                $this.PathManager.RemovePath($selectedPath)
                # Also remove alias if exists
                if ($prefs.repository.pathAliases.$selectedPath) {
                    $aliases = $prefs.repository.pathAliases
                    $aliases.PSObject.Properties.Remove($selectedPath)
                    $this.PreferencesService.SetPreference("repository", "pathAliases", $aliases)
                }
                return "[Success] Removed: $selectedPath"
            }
            "ALIAS" {
                return $this.SetPathAlias($selectedPath, $prefs, $GetLoc)
            }
            default { return $null }
        }
        return $null
    }
    
    hidden [string] SetPathAlias([string]$selectedPath, [PSCustomObject]$prefs, [scriptblock]$GetLoc) {
        $this.Console.ClearScreen()
        $this.Renderer.RenderHeader("SET ALIAS")
        Write-Host ""
        Write-Host "  Path: $selectedPath" -ForegroundColor Gray
        Write-Host "  Enter alias (leave empty to remove):" -ForegroundColor Yellow
        
        $this.Console.ShowCursor()
        $newAlias = Read-Host "  > "
        $this.Console.HideCursor()
        
        $currentAliases = if ($prefs.repository.pathAliases) { $prefs.repository.pathAliases } else { ([PSCustomObject]@{}) }
        
        if ([string]::IsNullOrWhiteSpace($newAlias)) {
            if ($currentAliases.PSObject.Properties.Name -contains $selectedPath) {
                $currentAliases.PSObject.Properties.Remove($selectedPath)
                $this.PreferencesService.SetPreference("repository", "pathAliases", $currentAliases)
                return "[Success] Alias removed."
            }
            return $null
        }
        
        # Select color
        $colors = @(
            @{ DisplayText = "Cyan (Default)"; Value = "Cyan" },
            @{ DisplayText = "Green"; Value = "Green" },
            @{ DisplayText = "Yellow"; Value = "Yellow" },
            @{ DisplayText = "Magenta"; Value = "Magenta" },
            @{ DisplayText = "Red"; Value = "Red" },
            @{ DisplayText = "White"; Value = "White" }
        )
        
        $colorConfig = [SelectionOptions]::new()
        $colorConfig.Title = "SELECT ALIAS COLOR"
        $colorConfig.Options = $colors
        $colorConfig.CurrentValue = "Cyan"
        
        $selectedColor = $this.OptionSelector.Show($colorConfig)
        if ($null -eq $selectedColor) { $selectedColor = "Cyan" }
        
        $aliasObj = [PSCustomObject]@{ Text = $newAlias; Color = $selectedColor }
        
        if ($currentAliases.PSObject.Properties.Name -contains $selectedPath) {
            $currentAliases.$selectedPath = $aliasObj
        } else {
            $currentAliases | Add-Member -NotePropertyName $selectedPath -NotePropertyValue $aliasObj -Force
        }
        
        $this.PreferencesService.SetPreference("repository", "pathAliases", $currentAliases)
        return "[Success] Alias set to '$newAlias' ($selectedColor)."
    }
    #endregion
    
    #region Result Helpers
    hidden [PSCustomObject] Changed([string]$msg, [int]$timeout) {
        return [PSCustomObject]@{ Updated = $true; Message = $msg; Timeout = $timeout }
    }
    
    hidden [PSCustomObject] NoChange() {
        return [PSCustomObject]@{ Updated = $false; Message = ""; Timeout = 0 }
    }
    #endregion
}
