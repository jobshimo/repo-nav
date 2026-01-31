<#
.SYNOPSIS
    PreferencesMenuController - Orchestrates the preferences menu.
    
.DESCRIPTION
    Refactored to follow SRP:
    - This class handles navigation/input and orchestration ONLY
    - PreferencesMenuRenderer handles all rendering
    - PreferencesActionDispatcher handles all action execution
    - ViewportManager handles viewport/pagination logic
#>

class PreferencesMenuController {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [UIRenderer] $Renderer
    [LocalizationService] $LocalizationService
    [OptionSelector] $OptionSelector
    
    # Delegated components
    [PreferencesMenuRenderer] $MenuRenderer
    [PreferencesActionDispatcher] $ActionDispatcher
    [ViewportManager] $Viewport
    
    PreferencesMenuController([object]$context) {
        $this.Console = $context.Console
        $this.PreferencesService = $context.PreferencesService
        $this.Renderer = $context.Renderer
        $this.OptionSelector = $context.OptionSelector
        $this.LocalizationService = $context.LocalizationService
        
        # Initialize components
        $this.MenuRenderer = [PreferencesMenuRenderer]::new($this.Console, $this.Renderer, $this.LocalizationService)
        $this.ActionDispatcher = [PreferencesActionDispatcher]::new($context)
        $this.Viewport = [ViewportManager]::new()
    }

    [bool] Show() {
        # Localization helper
        $GetLoc = { param($key, $def) if ($this.LocalizationService) { return $this.LocalizationService.Get($key) } return $def }

        $preferences = $this.PreferencesService.LoadPreferences()
        $running = $true
        $confirmationMessage = ""
        $confirmationTimeout = 0
        $fullRedrawNeeded = $true
        $listStartTop = 0
        
        try {
            $this.Console.HideCursor()
            
            while ($running) {
                try {
                    # 1. RENDER PHASE
                    if ($fullRedrawNeeded) {
                        $this.Console.ClearScreen()
                        $listStartTop = $this.MenuRenderer.RenderHeader((& $GetLoc "Pref.Title" "USER PREFERENCES"))
                        $fullRedrawNeeded = $false
                    }
                    
                    $this.Console.SetCursorPosition(0, $listStartTop)
                    
                    # 2. DATA PHASE - Build menu items
                    $preferenceItems = $this.GetPreferenceItems($preferences, $GetLoc)
                    $backItem = @{ Id = "BACK_BUTTON"; Name = (& $GetLoc "Pref.Back" "Back to main menu"); CurrentValue = ""; IsAction = $true }
                    $allItems = $preferenceItems + $backItem
                    
                    # 3. LAYOUT PHASE - Calculate viewport
                    $pageSize = $this.CalculatePageSize($listStartTop)
                    $this.Viewport.Initialize($allItems.Count, $pageSize, $this.Viewport.SelectedIndex)
                    
                    # 4. RENDER PHASE - Draw menu
                    $this.MenuRenderer.RenderMenu($allItems, $this.Viewport.SelectedIndex, $listStartTop, $this.Viewport.ViewportStart, $pageSize, $GetLoc)
                    
                    # 5. FOOTER PHASE
                    $footerLine = $listStartTop + $pageSize
                    $this.MenuRenderer.RenderFooter($confirmationMessage, $confirmationTimeout, $footerLine, $GetLoc)
                    
                    if ($confirmationTimeout -gt 0) { $confirmationTimeout-- } else { $confirmationMessage = "" }
                    
                    # 6. INPUT PHASE
                    $key = $this.Console.ReadKey()
                    $running = $this.HandleInput($key, $allItems, [ref]$preferences, $GetLoc, [ref]$fullRedrawNeeded, [ref]$confirmationMessage, [ref]$confirmationTimeout)
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
    
    # Handle keyboard input - returns $false to exit
    hidden [bool] HandleInput($key, [array]$allItems, [ref]$prefsRef, [scriptblock]$GetLoc, [ref]$redrawRef, [ref]$msgRef, [ref]$timeoutRef) {
        switch ($key.VirtualKeyCode) {
            ([Constants]::KEY_UP_ARROW) { 
                $this.Viewport.MoveUp() 
            }
            ([Constants]::KEY_DOWN_ARROW) { 
                $this.Viewport.MoveDown() 
            }
            ([Constants]::KEY_HOME) { 
                $this.Viewport.MoveToStart() 
            }
            ([Constants]::KEY_END) { 
                $this.Viewport.MoveToEnd() 
            }
            ([Constants]::KEY_LEFT_ARROW) { 
                return $false 
            }
            ([Constants]::KEY_Q) { 
                return $false 
            }
            ([Constants]::KEY_ESC) { 
                return $false 
            }
            ([Constants]::KEY_ENTER) {
                $selectedItem = $allItems[$this.Viewport.SelectedIndex]
                if ($selectedItem.Id -eq "BACK_BUTTON") {
                    return $false
                }
                
                # Dispatch action
                $result = $this.ActionDispatcher.Dispatch($selectedItem, $prefsRef.Value, $GetLoc)
                
                $redrawRef.Value = $true
                $this.Viewport.Reset()
                
                if ($result.Updated) {
                    $prefsRef.Value = $this.PreferencesService.LoadPreferences()
                    $msgRef.Value = $result.Message
                    $timeoutRef.Value = $result.Timeout
                }
            }
        }
        return $true
    }
    
    # Calculate available page size
    hidden [int] CalculatePageSize([int]$listStartTop) {
        $reserved = $listStartTop + 3
        $reservedFooter = 2
        $winHeight = $this.Console.GetWindowHeight()
        $maxPageSize = $winHeight - ($reserved + $reservedFooter)
        return [Math]::Max(5, $maxPageSize)
    }

    # Build menu items (data only, no rendering)
    hidden [array] GetPreferenceItems($preferences, $GetLoc) {
        $items = @()

        # Language
        $currentLang = $this.LocalizationService.GetCurrentLanguage()
        $langName = & $GetLoc "Lang.$currentLang" $currentLang
        $items += @{ Id = "language"; Name = (& $GetLoc "Pref.Language" "Language"); CurrentValue = $langName }

        # Show Headers
        $headersVal = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
        $headerDisplay = if ($headersVal) { (& $GetLoc "Pref.Value.Show") } else { (& $GetLoc "Pref.Value.Hide") }
        $items += @{ Id = "showHeaders"; Name = (& $GetLoc "Pref.ShowHeaders" "Show Headers"); CurrentValue = $headerDisplay }

        # Favorites On Top
        $favVal = if ($preferences.display.favoritesOnTop) { (& $GetLoc "Pref.Value.Top") } else { (& $GetLoc "Pref.Value.Original") }
        $items += @{ Id = "favoritesOnTop"; Name = (& $GetLoc "Pref.FavoritesPos" "Favorites Position"); CurrentValue = $favVal }

        # Background
        $items += @{ Id = "selectedBackground"; Name = (& $GetLoc "Pref.SelectedBg" "Selected Item Background"); CurrentValue = $preferences.display.selectedBackground }

        # Delimiter
        $items += @{ Id = "selectedDelimiter"; Name = (& $GetLoc "Pref.SelectedDelim" "Selected Item Delimiter"); CurrentValue = $preferences.display.selectedDelimiter }

        # Alias Position
        $posValKey = if ($preferences.display.aliasPosition -eq "Before") { "Pref.Value.Before" } else { "Pref.Value.After" }
        $posVal = & $GetLoc $posValKey $preferences.display.aliasPosition
        $items += @{ Id = "aliasPosition"; Name = (& $GetLoc "Pref.AliasPosition" "Alias Position"); CurrentValue = $posVal }
        
        # Alias Separator
        $sepMap = @{ " - " = "Pref.Value.SepHyphen"; " : " = "Pref.Value.SepColon"; " | " = "Pref.Value.SepPipe"; "None" = "Pref.Value.None" }
        $sepKey = if ($sepMap.ContainsKey($preferences.display.aliasSeparator)) { $sepMap[$preferences.display.aliasSeparator] } else { "Pref.Value.SepHyphen" }
        $sepVal = & $GetLoc $sepKey $preferences.display.aliasSeparator
        $items += @{ Id = "aliasSeparator"; Name = (& $GetLoc "Pref.AliasSeparator" "Alias Separator"); CurrentValue = $sepVal }
        
        # Alias Wrapper
        $wrapMap = @{ "None" = "Pref.Value.None"; "Parens" = "Pref.Value.WrapParens"; "Brackets" = "Pref.Value.WrapBrackets"; "Braces" = "Pref.Value.WrapBraces" }
        $wrapKey = if ($wrapMap.ContainsKey($preferences.display.aliasWrapper)) { $wrapMap[$preferences.display.aliasWrapper] } else { "Pref.Value.None" }
        $wrapVal = & $GetLoc $wrapKey $preferences.display.aliasWrapper
        $items += @{ Id = "aliasWrapper"; Name = (& $GetLoc "Pref.AliasWrapper" "Alias Style"); CurrentValue = $wrapVal }

        # Auto Git
        $mode = $preferences.git.autoLoadGitStatusMode
        if (-not $mode) { $mode = "None" }
        $display = & $GetLoc "Pref.AutoLoadGit.$mode" $mode
        $items += @{ Id = "autoLoadGit"; Name = (& $GetLoc "Pref.AutoLoadGit" "Auto-load Git Status"); CurrentValue = $display }
        
        # Manage Hidden
        $hiddenCount = if ($preferences.hidden.hiddenRepos) { $preferences.hidden.hiddenRepos.Count } else { 0 }
        $items += @{ Id = "manageHidden"; Name = (& $GetLoc "Pref.ManageHidden"); CurrentValue = "($hiddenCount)"; IsAction = $true }

        # Manage Paths
        $pathCount = if ($preferences.repository.paths) { $preferences.repository.paths.Count } else { 0 }
        $items += @{ Id = "managePaths"; Name = (& $GetLoc "Pref.ManagePaths" "Manage Repository Paths"); CurrentValue = "($pathCount)"; IsAction = $true }

        # Path Display
        $pathModeDisplay = if ($preferences.display.pathDisplayMode) { $preferences.display.pathDisplayMode } else { "Path" }
        $items += @{ Id = "pathDisplay"; Name = (& $GetLoc "Pref.PathDisplay" "Path Display Mode"); CurrentValue = $pathModeDisplay }

        # Menu Mode
        $menuModeDisplay = if ($preferences.display.menuMode) { $preferences.display.menuMode } else { "Full" }
        $items += @{ Id = "menuMode"; Name = (& $GetLoc "Pref.MenuMode" "Menu Display"); CurrentValue = $menuModeDisplay }

        # Custom Menu Sections (if Custom mode)
        if ($preferences.display.menuMode -eq 'Custom' -and $preferences.display.PSObject.Properties.Name -contains 'menuSections') {
            $sections = $preferences.display.menuSections
            $sectionKeys = @("navigation", "alias", "modules", "repository", "git", "tools")
            $sectionLabels = @{
                "navigation" = (& $GetLoc "UI.Group.Nav" "Navigation")
                "alias"      = (& $GetLoc "Pref.Group.Alias" "Alias")
                "modules"    = (& $GetLoc "UI.Group.Modules" "Modules")
                "repository" = (& $GetLoc "UI.Group.Repo" "Repository")
                "git"        = (& $GetLoc "Pref.Group.Git" "Git Status")
                "tools"      = (& $GetLoc "UI.Group.Tools" "Tools")
            }

            foreach ($secKey in $sectionKeys) {
                $isEnabled = if ($sections.PSObject.Properties.Name -contains $secKey) { $sections.$secKey } else { $true }
                $valDisplay = if ($isEnabled) { "[x] $(& $GetLoc "Pref.Value.Show")" } else { "[ ] $(& $GetLoc "Pref.Value.Show")" }
                
                $items += @{
                    Id = "section_$secKey"
                    Name = "  - $($sectionLabels[$secKey])"
                    CurrentValue = $valDisplay
                    IsSectionToggle = $true
                    SectionKey = $secKey
                    RawValue = $isEnabled
                }
            }
        }

        # DEV ONLY: Build Bundle
        $devToolsPath = Join-Path ([Constants]::ScriptRoot) "src\Dev\DevToolsCommand.ps1"
        if (Test-Path $devToolsPath) {
            $items += @{ Id = "buildBundle"; Name = "--- DEV: Build Bundle ---"; CurrentValue = ""; IsAction = $true; IsDev = $true }
        }

        return $items
    }
}
