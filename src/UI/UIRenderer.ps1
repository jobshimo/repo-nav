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
    [MenuRenderer] $MenuRenderer
    [RepositoryListRenderer] $RepoListRenderer
    
    # Constructor with dependency injection
    UIRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService, [LocalizationService]$localizationService, [MenuRenderer]$menuRenderer, [RepositoryListRenderer]$repoListRenderer) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
        $this.LocalizationService = $localizationService
        $this.MenuRenderer = $menuRenderer
        $this.RepoListRenderer = $repoListRenderer
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
        if ($null -ne $this.MenuRenderer) {
            return $this.MenuRenderer.RenderMenu($mode)
        }
        return 0
    }
# NOTE: Duplicated in RepositoryListRenderer for safety/encapsulation.
    # Eventually, RenderGitStatusFooter should move to a StatusRenderer.
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
    
    # Render visible repository list based on Viewport
    [void] RenderRepositoryList([NavigationState]$state, [int]$startLine) {
        if ($null -ne $this.RepoListRenderer) {
            $this.RepoListRenderer.RenderRepositoryList($state, $startLine)
        }
    }
    
    # Render repository item at specific line (optimized update)
    [void] UpdateRepositoryItemAt([int]$lineNumber, [RepositoryModel]$repo, [bool]$isSelected) {
        if ($null -ne $this.RepoListRenderer) {
            $this.RepoListRenderer.UpdateRepositoryItemAt($lineNumber, $repo, $isSelected)
        }
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

        # Handle empty/null repo case (empty folder)
        if ($null -eq $repo) {
            $this.Console.WriteColored("${lblStatus}: ", [Constants]::ColorLabel)
            $this.Console.WriteLineColored("Folder is empty", [Constants]::ColorHint)
            return
        }

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
