<#
.SYNOPSIS
    StatusRenderer - Handles rendering of the status footer and Git information
    
.DESCRIPTION
    Extracted from UIRenderer to follow SRP.
    Responsible for rendering the git status footer and formatting git status information.
#>

class StatusRenderer {
    [ConsoleHelper] $Console
    [LocalizationService] $LocalizationService

    # Constructor
    StatusRenderer([ConsoleHelper]$console, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.LocalizationService = $localizationService
    }

    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
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
}
