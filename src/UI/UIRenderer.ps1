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
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
    }
    
    # Render interactive workflow header with repository info
    [void] RenderWorkflowHeader([string]$title, [RepositoryModel]$repository) {
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ("{0}: " -f $this.GetLoc("UI.Group.Repo", "Repository")) -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
    }
    
    # Render interactive workflow header with additional info line
    [void] RenderWorkflowHeaderWithInfo([string]$title, [RepositoryModel]$repository, [string]$infoLabel, [string]$infoValue, [ConsoleColor]$infoColor) {
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "Repository: " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $repository.Name -ForegroundColor ([Constants]::ColorValue)
        Write-Host "$infoLabel : " -NoNewline -ForegroundColor ([Constants]::ColorPrompt)
        Write-Host $infoValue -ForegroundColor $infoColor
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host ""
    }
    
    # Render menu/instructions
    [void] RenderMenu() {
        Write-Host ""
        
        $grpNav = $this.GetLoc("UI.Group.Nav", "Navigation")
        $cmdNav = $this.GetLoc("Cmd.Desc.Nav", "Arrows | Enter=open")
        $cmdExit = $this.GetLoc("Cmd.Desc.Exit", "Q=quit")
        $cmdPref = $this.GetLoc("Cmd.Desc.Pref", "U=preferences")
        Write-Host "  ${grpNav}: $cmdNav | $cmdExit | $cmdPref" -ForegroundColor ([Constants]::ColorMenuText)

        $cmdAlias = $this.GetLoc("Cmd.Desc.Alias", "E=set | R=remove")
        Write-Host "  Alias:      $cmdAlias" -ForegroundColor ([Constants]::ColorMenuText)

        $grpMod = $this.GetLoc("UI.Group.Modules", "Modules")
        $cmdNpm = $this.GetLoc("Cmd.Desc.Npm", "I=install | X=remove")
        Write-Host "  ${grpMod}:    $cmdNpm" -ForegroundColor ([Constants]::ColorMenuText)

        $grpRepo = $this.GetLoc("UI.Group.Repo", "Repository")
        $cmdClone = $this.GetLoc("Cmd.Desc.RepoMgmt", "C=clone | Del=delete")
        $cmdFav = $this.GetLoc("Cmd.Desc.Favorite", "Space=favorite")
        Write-Host "  ${grpRepo}: $cmdClone | $cmdFav" -ForegroundColor ([Constants]::ColorMenuText)

        $cmdGit = $this.GetLoc("Cmd.Desc.Git", "L=load current | G=load all")
        Write-Host "  Git Status: $cmdGit" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host ""
        # The CursorStartLine in constants is 12 (approx). 
        # Header (3) + Blank (1) + Menu (5) + Blank (1) = 10 lines used before repo list
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
        
        # Determine name color
        $nameColor = if (-not $repo.HasNodeModules) { 
            [Constants]::ColorRepoWithoutModules  # Red si no tiene node_modules
        } elseif ($isSelected) { 
            $selectedTextColor  # Color optimizado según fondo
        } else { 
            [Constants]::ColorUnselected  # Blanco cuando no está seleccionado
        }
        
        $prefix = if ($isSelected) { "  > " } else { "    " }
        
        # Get git status display
        $gitDisplay = $this.GetGitStatusDisplay($repo.GitStatus)
        
        # Render prefix - usar color optimizado
        Write-Host $prefix -NoNewline -ForegroundColor $(if ($isSelected) { $selectedTextColor } else { [Constants]::ColorUnselected })
        
        # Render favorite indicator
        if ($repo.IsFavorite) {
            Write-Host "$([Constants]::FavoriteSymbol) " -NoNewline -ForegroundColor ([Constants]::ColorFavorite)
        } else {
            Write-Host "  " -NoNewline
        }
        
        # Render git indicator
        Write-Host "$($gitDisplay.Symbol) " -NoNewline -ForegroundColor $gitDisplay.Color
        
        # Render left delimiter
        if ($leftDelimiter -ne '') {
            if ($backgroundColor) {
                Write-Host $leftDelimiter -NoNewline -ForegroundColor $selectedTextColor -BackgroundColor $backgroundColor
            } else {
                Write-Host $leftDelimiter -NoNewline -ForegroundColor $selectedTextColor
            }
        }
        
        # Render repo name
        if ($backgroundColor) {
            Write-Host $repo.Name -NoNewline -ForegroundColor $nameColor -BackgroundColor $backgroundColor
        } else {
            Write-Host $repo.Name -NoNewline -ForegroundColor $nameColor
        }
        
        # Render right delimiter
        if ($rightDelimiter -ne '') {
            if ($backgroundColor) {
                Write-Host $rightDelimiter -NoNewline -ForegroundColor $selectedTextColor -BackgroundColor $backgroundColor
            } else {
                Write-Host $rightDelimiter -NoNewline -ForegroundColor $selectedTextColor
            }
        }
        
        # Render alias if exists (always without background)
        if ($repo.HasAlias -and $repo.AliasInfo) {
            $aliasText = " - $($repo.AliasInfo.Alias)"
            Write-Host $aliasText -ForegroundColor $repo.AliasInfo.Color
        } else {
            Write-Host ""
        }
    }

    # Render visible repository list based on Viewport
    [void] RenderRepositoryList([NavigationState]$state) {
        $repos = $state.Repositories
        $start = $state.ViewportStart
        $limit = $state.PageSize
        $total = $repos.Count
        
        for ($i = 0; $i -lt $limit; $i++) {
             $repoIndex = $start + $i
             if ($repoIndex -lt $total) {
                 # Ensure line is clean before rendering (important for scrolling/overlap)
                 $this.Console.ClearCurrentLine()
                 $this.RenderRepositoryItem($repos[$repoIndex], ($repoIndex -eq $state.SelectedIndex))
             } else {
                 # Clear/Empty line for empty slots in page
                 $this.Console.ClearCurrentLine()
                 Write-Host ""
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
            Write-Host "  > " -NoNewline -ForegroundColor ([Constants]::ColorSelected)
            if ($backgroundColor) {
                Write-Host $displayColor -ForegroundColor $color -BackgroundColor $backgroundColor
            } else {
                Write-Host $displayColor -ForegroundColor $color
            }
        } else {
            Write-Host "    " -NoNewline
            Write-Host $displayColor -ForegroundColor $color
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
    [void] RenderGitStatusFooter([RepositoryModel]$repo, [int]$totalRepos, [int]$loadedRepos) {
        # Line 1: Separator
        Write-Host ("=" * 55) -ForegroundColor ([Constants]::ColorSeparator)
        
        # Line 2: Counters
        Write-Host ("Repos: ") -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        Write-Host "$totalRepos" -NoNewline -ForegroundColor ([Constants]::ColorValue)
        Write-Host (" | Git Info: ") -NoNewline -ForegroundColor ([Constants]::ColorLabel)
        
        $counterColor = if ($loadedRepos -eq $totalRepos) { [Constants]::ColorCounterComplete } 
                       elseif ($loadedRepos -eq 0) { [Constants]::ColorCounterEmpty } 
                       else { [Constants]::ColorCounterPartial }
        Write-Host "$loadedRepos" -ForegroundColor $counterColor
        
        $lblStatus = $this.GetLoc("UI.Status", "Status")
        $lblBranch = $this.GetLoc("UI.Branch", "Branch")
        $lblNoGit = $this.GetLoc("UI.NoGit", "Not a git repository")
        $lblNotLoaded = $this.GetLoc("UI.NotLoaded", "Not loaded")

        # Line 3: Git status details
        if (-not $repo.HasGitStatusLoaded()) {
            Write-Host "${lblStatus}: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host "${lblNotLoaded} " -NoNewline -ForegroundColor ([Constants]::ColorHint)
            Write-Host "(" + $this.GetLoc("Cmd.Desc.Git", "press L to load current or G for all") + ")" -ForegroundColor ([Constants]::ColorWarning)
        } else {
            $gitStatus = $repo.GitStatus
            
            if (-not $gitStatus.IsGitRepo) {
                Write-Host "${lblStatus}: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host $lblNoGit -ForegroundColor ([Constants]::ColorHint)
            } else {
                Write-Host "${lblStatus}: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host "${lblBranch}: " -NoNewline -ForegroundColor ([Constants]::ColorHighlight)
                Write-Host $gitStatus.CurrentBranch -NoNewline -ForegroundColor ([Constants]::ColorValue)
                Write-Host " | " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                
                $gitDisplay = $this.GetGitStatusDisplay($gitStatus)
                Write-Host "$($gitDisplay.Symbol) $($gitDisplay.Description)" -ForegroundColor $gitDisplay.Color
            }
        }
        
        # Line 4: Separator
        Write-Host ("=" * 55) -ForegroundColor ([Constants]::ColorSeparator)
    }
    
    # Render error message
    [void] RenderError([string]$message) {
        $msg = $this.GetLoc("Error.Generic", "Error: {0}")
        # Simplistic format since we can't easily pass args to PS format for partial string
        # If message is already localized/dynamic, we just prepend Error if needed.
        # But here we just print as is usually.
        Write-Host "Error: $message" -ForegroundColor ([Constants]::ColorError)
    }
    
    # Render success message
    [void] RenderSuccess([string]$message) {
        Write-Host $message -ForegroundColor ([Constants]::ColorSuccess)
    }
    
    # Render warning message
    [void] RenderWarning([string]$message) {
        Write-Host $message -ForegroundColor ([Constants]::ColorWarning)
    }
}
