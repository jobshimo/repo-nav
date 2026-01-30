<#
.SYNOPSIS
    UIRenderer - Handles rendering of UI elements
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for rendering UI elements
    - ISP: Focused interface for different UI components
    - DIP: Depends on ConsoleHelper abstraction
    
    This class renders:
    - Headers and footers
    - Repository list items
    - Git status indicators
    - Color previews
#>

class UIRenderer {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [LocalizationService] $LocalizationService
    
    # Constructor with dependency injection
    UIRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
    }
    
    # Constructor with LocalizationService (overload/new signature)
    UIRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
        $this.LocalizationService = $localizationService
    }

    # Helper for localization
    [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }
    
    # Helper: Check preference for headers
    [bool] ShouldShowHeaders() {
        $preferences = $this.PreferencesService.LoadPreferences()
        if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') {
            return $preferences.display.showHeaders
        }
        return $true
    }

    # Render header
    # Render header
    # Render header
    # Render header
    # Overload 1: Title only
    [void] RenderHeader([string]$title) {
        $this.RenderHeader($title, "", "", [Constants]::ColorFavorite)
    }

    # Overload 2: Title + Subtitle
    [void] RenderHeader([string]$title, [string]$subtitle) {
        $this.RenderHeader($title, $subtitle, "", [Constants]::ColorFavorite)
    }

    # Overload 3: Title + Subtitle + Highlight (Default Color)
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight) {
        $this.RenderHeader($title, $subtitle, $highlight, [Constants]::ColorFavorite)
    }

    # Overload 4: Title + Subtitle + Highlight + Color
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight, [ConsoleColor]$highlightColor) {
        $this.RenderHeader($title, $subtitle, $highlight, $highlightColor, [Constants]::ColorSeparator)
    }

    # Overload 5: Title + Subtitle + Highlight + Color + BorderColor
    [void] RenderHeader([string]$title, [string]$subtitle, [string]$highlight, [ConsoleColor]$highlightColor, [ConsoleColor]$borderColor) {
        if ($this.ShouldShowHeaders()) {
            $this.Console.WriteSeparator("=", [Constants]::UIWidth, $borderColor)
            $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
            
            if (-not [string]::IsNullOrEmpty($subtitle)) {
                $this.Console.WriteSeparator("-", [Constants]::UIWidth, $borderColor)
                
                # Render subtitle logic with optional highlight
                $this.Console.WriteColored("    $subtitle", [Constants]::ColorValue)
                if (-not [string]::IsNullOrEmpty($highlight)) {
                    $this.Console.WriteColored(" [$highlight]", $highlightColor)
                }
                $this.Console.NewLine()
            }
            
            $this.Console.WriteSeparator("=", [Constants]::UIWidth, $borderColor)
        }
    }
    
    # Render breadcrumb for hierarchical navigation
    [void] RenderBreadcrumb([string]$path) {
        $backHint = $this.GetLoc("Nav.BackHint", "< back")
        $this.Console.WriteColored("  $backHint | ", [Constants]::ColorHint)
        $this.Console.WriteColored("Path: ", [Constants]::ColorLabel)
        $this.Console.WriteLineColored($path, [Constants]::ColorHighlight)
    }
    
    # Render simple workflow header (title only)
    [void] RenderWorkflowHeader([string]$title) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.NewLine()
    }
    
    # Render interactive workflow header with repository info
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteColored(("{0}: " -f $this.GetLoc("UI.Group.Repo", "Repository")), [Constants]::ColorPrompt)
        $this.Console.WriteLineColored($repository.Name, [Constants]::ColorValue)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.NewLine()
    }
    
    # Render interactive workflow header with additional info line
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteColored("Repository: ", [Constants]::ColorPrompt)
        $this.Console.WriteLineColored($repository.Name, [Constants]::ColorValue)
        $this.Console.WriteColored("$infoLabel : ", [Constants]::ColorPrompt)
        $this.Console.WriteLineColored($infoValue, $infoColor)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.NewLine()
    }
    
    # Render menu/instructions
    [int] RenderMenu([string]$mode) {
        $this.Console.NewLine()
        $linesRendered = 1 # Initial empty line
        
        if ($mode -eq 'Hidden') {
             return $linesRendered
        }
        
        # Minimal Mode: Only Nav and Exit (compact)
        if ($mode -eq 'Minimal') {
             $grpNav = $this.GetLoc("UI.Group.Nav", "Navigation")
             $cmdNav = $this.GetLoc("Cmd.Desc.Nav", "Arrows | Enter=open")
             $cmdExit = $this.GetLoc("Cmd.Desc.Exit", "Q=quit")
             $cmdPref = $this.GetLoc("Cmd.Desc.Pref", "U=preferences")
             
             $this.Console.WriteLineColored("  $cmdNav | $cmdExit | $cmdPref", [Constants]::ColorMenuText)
             $linesRendered++
             $this.Console.NewLine()
             $linesRendered++
             return $linesRendered
        }
        
        # Determine visibility based on mode
        $showNav     = $true
        $showAlias   = $true
        $showModules = $true
        $showRepo    = $true
        $showGit     = $true
        $showTools   = $true
        
        if ($mode -eq 'Custom') {
            $preferences = $this.PreferencesService.LoadPreferences()
            if ($preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                $sections = $preferences.display.menuSections
                $showNav     = if ($sections.PSObject.Properties.Name -contains 'navigation') { $sections.navigation } else { $true }
                $showAlias   = if ($sections.PSObject.Properties.Name -contains 'alias') { $sections.alias } else { $true }
                $showModules = if ($sections.PSObject.Properties.Name -contains 'modules') { $sections.modules } else { $true }
                $showRepo    = if ($sections.PSObject.Properties.Name -contains 'repository') { $sections.repository } else { $true }
                $showGit     = if ($sections.PSObject.Properties.Name -contains 'git') { $sections.git } else { $true }
                $showTools   = if ($sections.PSObject.Properties.Name -contains 'tools') { $sections.tools } else { $true }
            }
        }
        
        # Common constants
        $labelWidth = 13 
        
        if ($showNav) {
            $linesRendered += $this.RenderSectionNavigation($labelWidth)
        }
        
        if ($showAlias) {
            $linesRendered += $this.RenderSectionAlias($labelWidth)
        }
        
        if ($showModules) {
            $linesRendered += $this.RenderSectionModules($labelWidth)
        }
        
        if ($showRepo) {
            $linesRendered += $this.RenderSectionRepository($labelWidth)
        }
        
        if ($showGit) {
            $linesRendered += $this.RenderSectionGitStatus($labelWidth)
        }
        
        if ($showTools) {
             $linesRendered += $this.RenderSectionTools($labelWidth)
        }
        
        $this.Console.NewLine()
        $linesRendered++
        
        return $linesRendered
    }
    
    # Helper: Render Navigation Section
    hidden [int] RenderSectionNavigation([int]$labelWidth) {
        $grpNav = $this.GetLoc("UI.Group.Nav", "Navigation")
        $cmdNav = $this.GetLoc("Cmd.Desc.Nav", "Arrows | Enter=open")
        $cmdExit = $this.GetLoc("Cmd.Desc.Exit", "Q=quit")
        # Prefs moved to Tools
        
        $lblNav = "${grpNav}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblNav $cmdNav | $cmdExit", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Alias Section
    hidden [int] RenderSectionAlias([int]$labelWidth) {
        $cmdAlias = $this.GetLoc("Cmd.Desc.Alias", "E=set | R=remove")
        $lblAlias = "Alias:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblAlias $cmdAlias", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Modules Section
    hidden [int] RenderSectionModules([int]$labelWidth) {
        $grpMod = $this.GetLoc("UI.Group.Modules", "Modules")
        $cmdNpm = $this.GetLoc("Cmd.Desc.Npm", "I=install | X=remove")
        $lblMod = "${grpMod}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblMod $cmdNpm", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Repository Section
    hidden [int] RenderSectionRepository([int]$labelWidth) {
        $grpRepo = $this.GetLoc("UI.Group.Repo", "Repository")
        $cmdClone = $this.GetLoc("Cmd.Desc.RepoMgmt", "C=clone | Del=delete")
        $cmdFav = $this.GetLoc("Cmd.Desc.Favorite", "Space=favorite")
        $cmdHide = $this.GetLoc("Cmd.Desc.Hide", "H=hide | V=vis")
        
        $lblRepo = "${grpRepo}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblRepo $cmdClone | $cmdFav | $cmdHide", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Git Status Section
    hidden [int] RenderSectionGitStatus([int]$labelWidth) {
        $cmdGit = $this.GetLoc("Cmd.Desc.Git", "L=load current | G=load all")
        $lblGit = "Git Status:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblGit $cmdGit", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Tools Section
    hidden [int] RenderSectionTools([int]$labelWidth) {
        $grpTool = $this.GetLoc("UI.Group.Tools", "Tools")
        $cmdPref = $this.GetLoc("Cmd.Desc.Pref", "U=preferences")
        $cmdFolder = $this.GetLoc("Cmd.Desc.CreateFolder", "N=New Folder")
        $cmdSearch = $this.GetLoc("Cmd.Desc.Search", "S=Search")
        $cmdFlow = $this.GetLoc("Cmd.Desc.GitFlow", "B=Flow")
        
        $lblTool = "${grpTool}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblTool $cmdSearch | $cmdFolder | $cmdFlow | $cmdPref", [Constants]::ColorMenuText)
        return 1
    }


    
    # Render a single repository list item
    [void] RenderRepositoryItem([RepositoryModel]$repo, [bool]$isSelected) {
        $preferences = $this.PreferencesService.LoadPreferences()

        # Get user-configured background color and delimiter
        $backgroundColor = $null
        $selectedTextColor = [Constants]::ColorSelected
        $leftDelimiter = ''
        $rightDelimiter = ''
        
        if ($isSelected) {
            $bgColor = $preferences.display.selectedBackground
            
            if ($bgColor -ne 'None') {
                $backgroundColor = $bgColor
            }
            
            # Get optimal text color based on background for better contrast
            $selectedTextColor = [Constants]::GetTextColorForBackground($bgColor)
            
            # Get delimiter
            $delimiterName = $preferences.display.selectedDelimiter
            $delimiter = [Constants]::AvailableDelimiters | Where-Object { $_.Name -eq $delimiterName } | Select-Object -First 1
            if ($delimiter) {
                $leftDelimiter = $delimiter.Left
                $rightDelimiter = $delimiter.Right
            }
        }
        

        
        # Instantiate ViewModel
        $vm = [RepositoryViewModel]::new($repo, $preferences)
        
        # Get color from ViewModel
        $nameColor = if ($repo.IsHidden -and -not $isSelected) { 
            [Constants]::ColorHint 
        } else { 
            $vm.GetNameColor($isSelected) 
        }
        
        # Get prefix from ViewModel
        $prefix = $vm.GetPrefix($isSelected)
        
        # Render prefix - usar color optimizado
        $this.Console.WriteColored($prefix, $(if ($isSelected) { $selectedTextColor } else { [Constants]::ColorUnselected }))
        
        # Render favorite indicator (not for containers)
        if (-not $repo.IsContainer -and $repo.IsFavorite) {
            $this.Console.WriteColored("$([Constants]::FavoriteSymbol) ", [Constants]::ColorFavorite)
        } elseif ($repo.IsContainer) {
            # Container indicator
            $this.Console.WriteColored("+ ", [Constants]::ColorHighlight)
        } else {
            $this.Console.Write("  ")
        }
        
        # Render git indicator (only for non-containers)
        if ($repo.IsContainer) {
            $this.Console.Write("  ")  # No git status for containers
        } else {
            $gitDisplay = $vm.GetGitStatusDisplay()
            $this.Console.WriteColored("$($gitDisplay.Symbol) ", $gitDisplay.Color)
        }
        
        # Alias Configuration
        $aliasPosition = if ($preferences.display.PSObject.Properties.Name -contains 'aliasPosition') { $preferences.display.aliasPosition } else { "After" }
        $aliasSeparator = if ($preferences.display.PSObject.Properties.Name -contains 'aliasSeparator') { $preferences.display.aliasSeparator } else { " - " }
        $aliasWrapper = if ($preferences.display.PSObject.Properties.Name -contains 'aliasWrapper') { $preferences.display.aliasWrapper } else { "None" }

        # Prepare Alias Content
        $shouldRenderAlias = $repo.HasAlias -and $repo.AliasInfo -and (-not $repo.IsContainer)
        $aliasTextToRender = ""
        
        if ($shouldRenderAlias) {
            $rawAlias = $repo.AliasInfo.Alias
            $aliasTextToRender = switch ($aliasWrapper) {
                "Parens"   { "($rawAlias)" }
                "Brackets" { "[$rawAlias]" }
                "Braces"   { "{$rawAlias}" }
                Default    { $rawAlias }
            }
        }

        # Define Rendering Blocks for reused logic
        $RenderAliasBlock = {
             if ($shouldRenderAlias) {
                 $this.Console.WriteColored($aliasTextToRender, $repo.AliasInfo.Color)
             }
        }
        
        $RenderSeparatorBlock = {
            if ($shouldRenderAlias -and $aliasSeparator -ne "None") {
                 $this.Console.WriteColored($aliasSeparator, $repo.AliasInfo.Color)
            }
        }

        # Render BEFORE: Name
        if ($aliasPosition -eq "Before" -and (-not $repo.IsContainer)) {
             & $RenderAliasBlock
             & $RenderSeparatorBlock
        }

        # Render left delimiter
        if ($leftDelimiter -ne '') {
            if ($backgroundColor) {
                $this.Console.WriteWithBackground($leftDelimiter, $selectedTextColor, $backgroundColor)
            } else {
                $this.Console.WriteColored($leftDelimiter, $selectedTextColor)
            }
        }
        
        # Render repo name
        if ($backgroundColor) {
            $this.Console.WriteWithBackground($repo.Name, $nameColor, $backgroundColor)
        } else {
            $this.Console.WriteColored($repo.Name, $nameColor)
        }
        
        # Render (Hidden) suffix if applicable
        if ($repo.IsHidden) {
             $hiddenSuffix = " [Hidden]"
             $suffixColor = if ($isSelected) { $selectedTextColor } else { [Constants]::ColorHint }
             
             if ($backgroundColor) {
                 $this.Console.WriteWithBackground($hiddenSuffix, $suffixColor, $backgroundColor)
             } else {
                 $this.Console.WriteColored($hiddenSuffix, $suffixColor)
             }
        }
        
        # Render right delimiter
        if ($rightDelimiter -ne '') {
            if ($backgroundColor) {
                $this.Console.WriteWithBackground($rightDelimiter, $selectedTextColor, $backgroundColor)
            } else {
                $this.Console.WriteColored($rightDelimiter, $selectedTextColor)
            }
        }
        
        # Render AFTER: Contained Count or Alias
        if ($repo.IsContainer) {
            $countText = " ($($repo.ContainedRepoCount))"
            $this.Console.WriteColored($countText, [Constants]::ColorInfo)
        }
        elseif ($aliasPosition -eq "After") {
            & $RenderSeparatorBlock
            & $RenderAliasBlock
        }
        # Explicitly NO newline at the end. Caller handles positioning.
        
        # Ensure the rest of the line is cleared (prevents artifacts without full line clear)
        $this.Console.ClearRestOfLine()
    }

    # Render visible repository list based on Viewport
    [void] RenderRepositoryList([NavigationState]$state, [int]$startLine) {
        $repos = $state.Repositories
        $start = $state.ViewportStart
        $limit = $state.PageSize
        $total = $repos.Count
        
        for ($i = 0; $i -lt $limit; $i++) {
             $currentLine = $startLine + $i
             $this.Console.SetCursorPosition(0, $currentLine)
             
             $repoIndex = $start + $i
             if ($repoIndex -lt $total) {
                 $this.RenderRepositoryItem($repos[$repoIndex], ($repoIndex -eq $state.SelectedIndex))
             } else {
                 # Clear the line if there's no repo to display (prevents ghost items)
                 $this.Console.ClearCurrentLine()
             }
        }
    }
    
    # Render repository item at specific line (optimized update)
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.SetCursorPosition(0, $lineNumber)
        # Optimized: Removed ClearCurrentLine()

        $this.RenderRepositoryItem($repo, $isSelected)
    }
    
    # Render color selection item
    [void] RenderColorItem([string]$color, [bool]$isSelected) {
        $backgroundColor = $null
        if ($isSelected) {
            $preferences = $this.PreferencesService.LoadPreferences()
            $bgColor = $preferences.display.selectedBackground
            if ($bgColor -ne 'None') {
                $backgroundColor = $bgColor
            }
        }
        
        $displayColor = $this.GetLoc("Color.$color", $color)

        if ($isSelected) {
            $this.Console.WriteColored("  > ", [Constants]::ColorSelected)
            if ($backgroundColor) {
                $this.Console.WriteWithBackground($displayColor, $color, $backgroundColor)
            } else {
                $this.Console.WriteColored($displayColor, $color)
            }
            $this.Console.NewLine()
        } else {
            $this.Console.Write("    ")
            $this.Console.WriteLineColored($displayColor, $color)
        }
        # Ensure tail is cleared (if not using WriteLine logic, but here we do?)
        # Actually RenderColorItem uses WriteLineColored which adds newline.
        # We should change it to WriteColored + ClearRestOfLine + NewLine if we want to support non-clearing updates.
        # For now, let's just leave it but UpdateColorItemAt needs care.
    }
    
    # Update color item at specific line
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.ClearCurrentLine() # Verify if we can remove this for ColorItems too

        $this.RenderColorItem($color, $isSelected)
    }
    
    # Clear the git status footer area (4 lines)
    [void] ClearGitStatusFooter([int]$startLine) {
        for ($i = 0; $i -lt 4; $i++) {
            $this.Console.SetCursorPosition(0, $startLine + $i)
            $this.Console.ClearCurrentLine()
        }
        $this.Console.SetCursorPosition(0, $startLine)
    }
    
    # Render git status footer
    # Now receives additional counts: totalItems (all), totalRepos (only non-containers), loadedRepos (git status loaded)
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalItems, [int]$totalRepos, [int]$loadedRepos, [int]$currentIndex, [bool]$showHidden) {
        # Line 1: Separator
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Line 2: Counters
        $currentPos = $currentIndex + 1
        $this.Console.WriteColored("Item: ", [Constants]::ColorLabel)
        $this.Console.WriteColored("$currentPos/$totalItems", [Constants]::ColorValue)
        
        # Show repos count only if different from total items (means there are containers)
        if ($totalRepos -ne $totalItems) {
            $this.Console.WriteColored(" | Repos: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$totalRepos", [Constants]::ColorValue)
        }
        
        # Hidden visual indicator
        if ($showHidden) {
             $this.Console.WriteColored(" | ", [Constants]::ColorLabel)
             $this.Console.WriteColored("SHOW HIDDEN", [Constants]::ColorWarning)
        }
        
        $this.Console.WriteColored(" | Git Info: ", [Constants]::ColorLabel)
        
        $counterColor = if ($loadedRepos -eq $totalRepos) { [Constants]::ColorCounterComplete } 
                       elseif ($loadedRepos -eq 0) { [Constants]::ColorCounterEmpty } 
                       else { [Constants]::ColorCounterPartial }
        
        # Write last part and clear rest of line
        $this.Console.WriteColored("$loadedRepos/$totalRepos", $counterColor)
        $this.Console.ClearRestOfLine()
        $this.Console.NewLine()
        
        $lblStatus = $this.GetLoc("UI.Status", "Status")
        $lblBranch = $this.GetLoc("UI.Branch", "Branch")
        $lblNoGit = $this.GetLoc("UI.NoGit", "Not a git repository")
        $lblNotLoaded = $this.GetLoc("UI.NotLoaded", "Not loaded")
        $lblContainer = $this.GetLoc("UI.Container", "Folder (contains repos)")

        # Handle empty/null repo case (empty folder)
        if ($null -eq $repo) {
            $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("Folder is empty", [Constants]::ColorHint)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
            return
        }


        # Line 3: Git status details
        # If it's a container, show that it's a folder, not a repo
        if ($repo.IsContainer) {
            $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
            $this.Console.WriteColored($lblContainer, [Constants]::ColorHighlight)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
        }
        elseif (-not $repo.HasGitStatusLoaded()) {
            $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("${lblNotLoaded} ", [Constants]::ColorHint)
            $this.Console.WriteColored(("(" + $this.GetLoc("Cmd.Desc.Git", "press L to load current or G for all") + ")"), [Constants]::ColorWarning)
            $this.Console.ClearRestOfLine()
            $this.Console.NewLine()
        } else {
            # Use ViewModel for consistent display logic
            $vm = [RepositoryViewModel]::new($repo, $this.PreferencesService.LoadPreferences())
            $gitStatus = $repo.GitStatus
            
            if (-not $gitStatus.IsGitRepo) {
                $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
                $this.Console.WriteColored($lblNoGit, [Constants]::ColorHint)
                $this.Console.ClearRestOfLine()
                $this.Console.NewLine()
            } else {
                $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
                $this.Console.WriteColored("${lblBranch}: ", [Constants]::ColorHighlight)
                $this.Console.WriteColored($gitStatus.CurrentBranch, [Constants]::ColorValue)
                $this.Console.WriteColored(" | ", [Constants]::ColorLabel)
                
                $gitDisplay = $vm.GetGitStatusDisplay()
                $this.Console.WriteColored("$($gitDisplay.Symbol) $($gitDisplay.Description)", $gitDisplay.Color)
                $this.Console.ClearRestOfLine()
                $this.Console.NewLine()
            }
        }
        
        # Line 4: Separator
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
    }
    
    # Render error message
    [void] RenderError([string]$message) {
        $msg = $this.GetLoc("Error.Generic", "Error: {0}")
        # Simplistic format since we can't easily pass args to PS format for partial string
        # If message is already localized/dynamic, we just prepend Error if needed.
        # But here we just print as is usually.
        $this.Console.WriteLineColored("Error: $message", [Constants]::ColorError)
    }
    
    # Render success message
    [void] RenderSuccess([string]$message) {
        $this.Console.WriteLineColored($message, [Constants]::ColorSuccess)
    }
    
    # Render warning message
    [void] RenderWarning([string]$message) {
        $this.Console.WriteLineColored($message, [Constants]::ColorWarning)
    }
}
