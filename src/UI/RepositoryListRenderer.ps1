<#
.SYNOPSIS
    RepositoryListRenderer - Handles rendering of the repository list
    
.DESCRIPTION
    Extracted from UIRenderer to follow SRP.
    Responsible for rendering the list of repositories and individual items.
#>

class RepositoryListRenderer {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService

    # Constructor
    RepositoryListRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
    }

    # Get git status display info (Private helper)
    hidden [hashtable] GetGitStatusDisplay([GitStatusModel]$gitStatus) {
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
        
        # Render prefix - use optimized color
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
}
