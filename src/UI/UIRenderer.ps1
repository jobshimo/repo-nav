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
    
    # Render header
    [void] RenderHeader([string]$title) {
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("    $title", [Constants]::ColorHeader)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
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
        
        if ($mode -eq 'Custom') {
            $preferences = $this.PreferencesService.LoadPreferences()
            if ($preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                $sections = $preferences.display.menuSections
                $showNav     = if ($sections.PSObject.Properties.Name -contains 'navigation') { $sections.navigation } else { $true }
                $showAlias   = if ($sections.PSObject.Properties.Name -contains 'alias') { $sections.alias } else { $true }
                $showModules = if ($sections.PSObject.Properties.Name -contains 'modules') { $sections.modules } else { $true }
                $showRepo    = if ($sections.PSObject.Properties.Name -contains 'repository') { $sections.repository } else { $true }
                $showGit     = if ($sections.PSObject.Properties.Name -contains 'git') { $sections.git } else { $true }
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
        
        $this.Console.NewLine()
        $linesRendered++
        
        return $linesRendered
    }
    
    # Helper: Render Navigation Section
    hidden [int] RenderSectionNavigation([int]$labelWidth) {
        $grpNav = $this.GetLoc("UI.Group.Nav", "Navigation")
        $cmdNav = $this.GetLoc("Cmd.Desc.Nav", "Arrows | Enter=open")
        $cmdExit = $this.GetLoc("Cmd.Desc.Exit", "Q=quit")
        $cmdPref = $this.GetLoc("Cmd.Desc.Pref", "U=preferences")
        
        $lblNav = "${grpNav}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblNav $cmdNav | $cmdExit | $cmdPref", [Constants]::ColorMenuText)
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
        $lblRepo = "${grpRepo}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblRepo $cmdClone | $cmdFav", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Git Status Section
    hidden [int] RenderSectionGitStatus([int]$labelWidth) {
        $cmdGit = $this.GetLoc("Cmd.Desc.Git", "L=load current | G=load all")
        $lblGit = "Git Status:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblGit $cmdGit", [Constants]::ColorMenuText)
        return 1
    }

    # Get git status display info
    [hashtable] GetGitStatusDisplay([GitStatusModel]$gitStatus) {
        if (-not $gitStatus -or -not $gitStatus.IsGitRepo) {
            return @{
                Symbol = "?"
                Color = ([Constants]::ColorGitUnknown)
                Description = "Not a git repository"
            }
        }
        
        # Priority: Uncommitted > Unpushed > Clean
        if ($gitStatus.HasUncommittedChanges) {
            return @{
                Symbol = [Constants]::GitSymbolUncommitted
                Color = ([Constants]::ColorGitUncommitted)
                Description = "Uncommitted changes"
            }
        }
        
        if ($gitStatus.HasUnpushedCommits) {
            return @{
                Symbol = [Constants]::GitSymbolUnpushed
                Color = ([Constants]::ColorGitUnpushed)
                Description = "Unpushed commits"
            }
        }
        
        return @{
            Symbol = [Constants]::GitSymbolClean
            Color = ([Constants]::ColorGitClean)
            Description = "Clean repository"
        }
    }
    
    # Render a single repository list item
    [void] RenderRepositoryItem([RepositoryModel]$repo, [bool]$isSelected) {
        # Get user-configured background color and delimiter
        $backgroundColor = $null
        $selectedTextColor = [Constants]::ColorSelected
        $leftDelimiter = ''
        $rightDelimiter = ''
        
        if ($isSelected) {
            $preferences = $this.PreferencesService.LoadPreferences()
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
        
        # Determine name color - containers use Cyan, repos use normal logic
        $nameColor = if ($repo.IsContainer) {
            [Constants]::ColorHighlight  # Cyan for containers
        } elseif (-not $repo.HasNodeModules) { 
            [Constants]::ColorRepoWithoutModules  # Red si no tiene node_modules
        } elseif ($isSelected) { 
            $selectedTextColor  # Color optimizado según fondo
        } else { 
            [Constants]::ColorUnselected  # Blanco cuando no está seleccionado
        }
        
        $prefix = if ($isSelected) { "  > " } else { "    " }
        
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
            $gitDisplay = $this.GetGitStatusDisplay($repo.GitStatus)
            $this.Console.WriteColored("$($gitDisplay.Symbol) ", $gitDisplay.Color)
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
        
        # Render right delimiter
        if ($rightDelimiter -ne '') {
            if ($backgroundColor) {
                $this.Console.WriteWithBackground($rightDelimiter, $selectedTextColor, $backgroundColor)
            } else {
                $this.Console.WriteColored($rightDelimiter, $selectedTextColor)
            }
        }
        
        # For containers, show count of items inside (could be repos or more folders)
        if ($repo.IsContainer) {
            $countText = " ($($repo.ContainedRepoCount))"
            $this.Console.WriteColored($countText, [Constants]::ColorInfo)
        }
        # Render alias if exists (always without background) - only for non-containers
        elseif ($repo.HasAlias -and $repo.AliasInfo) {
            $aliasText = " - $($repo.AliasInfo.Alias)"
            $this.Console.WriteColored($aliasText, $repo.AliasInfo.Color)
        } else {
             # Do nothing or just ensure no residual text (handled by ClearCurrentLine)
             # Write-Host "" -NoNewline 
        }
        # Explicitly NO newline at the end. Caller handles positioning.
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
             $this.Console.ClearCurrentLine()
             
             $repoIndex = $start + $i
             if ($repoIndex -lt $total) {
                 $this.RenderRepositoryItem($repos[$repoIndex], ($repoIndex -eq $state.SelectedIndex))
             } else {
                 # Just ensure the line is empty (handled by ClearCurrentLine above)
             }
        }
    }
    
    # Render repository item at specific line (optimized update)
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.ClearCurrentLine()
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
    }
    
    # Update color item at specific line
    [void] UpdateColorItemAt([int]$lineNumber, [string]$color, [bool]$isSelected) {
        $this.Console.SetCursorPosition(0, $lineNumber)
        $this.Console.ClearCurrentLine()
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
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalItems, [int]$totalRepos, [int]$loadedRepos, [int]$currentIndex) {
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
        
        $this.Console.WriteColored(" | Git Info: ", [Constants]::ColorLabel)
        
        $counterColor = if ($loadedRepos -eq $totalRepos) { [Constants]::ColorCounterComplete } 
                       elseif ($loadedRepos -eq 0) { [Constants]::ColorCounterEmpty } 
                       else { [Constants]::ColorCounterPartial }
        $this.Console.WriteLineColored("$loadedRepos/$totalRepos", $counterColor)
        
        $lblStatus = $this.GetLoc("UI.Status", "Status")
        $lblBranch = $this.GetLoc("UI.Branch", "Branch")
        $lblNoGit = $this.GetLoc("UI.NoGit", "Not a git repository")
        $lblNotLoaded = $this.GetLoc("UI.NotLoaded", "Not loaded")
        $lblContainer = $this.GetLoc("UI.Container", "Folder (contains repos)")

        # Line 3: Git status details
        # If it's a container, show that it's a folder, not a repo
        if ($repo.IsContainer) {
            $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
            $this.Console.WriteLineColored($lblContainer, [Constants]::ColorHighlight)
        }
        elseif (-not $repo.HasGitStatusLoaded()) {
            $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("${lblNotLoaded} ", [Constants]::ColorHint)
            $this.Console.WriteLineColored(("(" + $this.GetLoc("Cmd.Desc.Git", "press L to load current or G for all") + ")"), [Constants]::ColorWarning)
        } else {
            $gitStatus = $repo.GitStatus
            
            if (-not $gitStatus.IsGitRepo) {
                $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
                $this.Console.WriteLineColored($lblNoGit, [Constants]::ColorHint)
            } else {
                $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
                $this.Console.WriteColored("${lblBranch}: ", [Constants]::ColorHighlight)
                $this.Console.WriteColored($gitStatus.CurrentBranch, [Constants]::ColorValue)
                $this.Console.WriteColored(" | ", [Constants]::ColorLabel)
                
                $gitDisplay = $this.GetGitStatusDisplay($gitStatus)
                $this.Console.WriteLineColored("$($gitDisplay.Symbol) $($gitDisplay.Description)", $gitDisplay.Color)
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
