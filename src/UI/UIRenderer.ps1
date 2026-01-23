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
    
    # Constructor with dependency injection
    UIRenderer([ConsoleHelper]$console) {
        $this.Console = $console
    }
    
    # Render header
    [void] RenderHeader([string]$title) {
        $separator = "=" * 55
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
        Write-Host "    $title" -ForegroundColor ([Constants]::ColorHeader)
        Write-Host $separator -ForegroundColor ([Constants]::ColorSeparator)
    }
    
    # Render menu/instructions
    [void] RenderMenu() {
        Write-Host ""
        Write-Host "  Navigation: Arrows | Enter=open | Q=quit | U=preferences" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Aliases:    E=set | R=remove" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Modules:    I=install | X=remove" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Repository: C=clone | Del=delete | F=favorite" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host "  Git Status: L=load current | G=load all missing" -ForegroundColor ([Constants]::ColorMenuText)
        Write-Host ""
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
        # Determine colors
        $nameColor = if (-not $repo.HasNodeModules) { 
            [Constants]::ColorRepoWithoutModules
        } elseif ($isSelected) { 
            [Constants]::ColorSelected
        } else { 
            [Constants]::ColorUnselected
        }
        
        $backgroundColor = if ($isSelected) { [Constants]::ColorSelectedBackground } else { $null }
        $prefix = if ($isSelected) { "  > " } else { "    " }
        
        # Get git status display
        $gitDisplay = $this.GetGitStatusDisplay($repo.GitStatus)
        
        # Render prefix
        Write-Host $prefix -NoNewline -ForegroundColor $(if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorUnselected })
        
        # Render favorite indicator
        if ($repo.IsFavorite) {
            Write-Host "$([Constants]::FavoriteSymbol) " -NoNewline -ForegroundColor ([Constants]::ColorFavorite)
        } else {
            Write-Host "  " -NoNewline
        }
        
        # Render git indicator
        Write-Host "$($gitDisplay.Symbol) " -NoNewline -ForegroundColor $gitDisplay.Color
        
        # Render repo name
        if ($backgroundColor) {
            Write-Host $repo.Name -NoNewline -ForegroundColor $nameColor -BackgroundColor $backgroundColor
        } else {
            Write-Host $repo.Name -NoNewline -ForegroundColor $nameColor
        }
        
        # Render alias if exists
        if ($repo.HasAlias -and $repo.AliasInfo) {
            $aliasText = " - $($repo.AliasInfo.Alias)"
            if ($backgroundColor) {
                Write-Host $aliasText -ForegroundColor $repo.AliasInfo.Color -BackgroundColor $backgroundColor
            } else {
                Write-Host $aliasText -ForegroundColor $repo.AliasInfo.Color
            }
        } else {
            Write-Host ""
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
        if ($isSelected) {
            Write-Host "  > " -NoNewline -ForegroundColor ([Constants]::ColorSelected)
            Write-Host $color -ForegroundColor $color -BackgroundColor ([Constants]::ColorSelectedBackground)
        } else {
            Write-Host "    " -NoNewline
            Write-Host $color -ForegroundColor $color
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
        $width = $this.Console.GetWindowWidth()
        
        # Line 1: Separator
        Write-Host ("=" * 55) -ForegroundColor ([Constants]::ColorSeparator)
        
        # Line 2: Counters
        if ($totalRepos -gt 0) {
            Write-Host "Repos: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host "$totalRepos" -NoNewline -ForegroundColor ([Constants]::ColorValue)
            Write-Host " | Git Info: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            
            $counterColor = if ($loadedRepos -eq $totalRepos) { [Constants]::ColorCounterComplete } 
                           elseif ($loadedRepos -eq 0) { [Constants]::ColorCounterEmpty } 
                           else { [Constants]::ColorCounterPartial }
            Write-Host "$loadedRepos" -ForegroundColor $counterColor
        }
        
        # Line 3: Git status details
        if (-not $repo.HasGitStatusLoaded()) {
            Write-Host "Git Status: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
            Write-Host "Not loaded " -NoNewline -ForegroundColor ([Constants]::ColorHint)
            Write-Host "(press L to load current or G for all)" -ForegroundColor ([Constants]::ColorWarning)
        } else {
            $gitStatus = $repo.GitStatus
            
            if (-not $gitStatus.IsGitRepo) {
                Write-Host "Git Status: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host "Not a git repository" -ForegroundColor ([Constants]::ColorHint)
            } else {
                Write-Host "Git Status: " -NoNewline -ForegroundColor ([Constants]::ColorLabel)
                Write-Host "Branch: " -NoNewline -ForegroundColor ([Constants]::ColorHighlight)
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
