<#
.SYNOPSIS
    SearchView - Interactive search interface for repositories
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only responsible for search UI rendering and interaction
    - DIP: Depends on ConsoleHelper, UIRenderer, SearchService abstractions
    
    This view provides:
    - Real-time filtering as user types
    - Seamless navigation between search input and results list
    - Keyboard-driven interface (Tab, Arrows, Enter, Esc)
#>

class SearchView {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [SearchService] $SearchService
    [LocalizationService] $LocalizationService
    
    # Constructor with dependency injection
    SearchView([ConsoleHelper]$console, [UIRenderer]$renderer, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.SearchService = [SearchService]::new()
        $this.LocalizationService = $localizationService
    }
    
    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }
    
    <#
    .SYNOPSIS
        Shows the search interface and returns the selected repository
        
    .PARAMETER allRepos
        Complete list of repositories to search
        
    .PARAMETER currentRepo
        Currently selected repository (to preserve selection if in results)
        
    .RETURNS
        Hashtable with: { SelectedRepo, SelectedIndex, Cancelled }
    #>
    [hashtable] Show([array]$allRepos, [object]$currentRepo) {
        if ($null -eq $allRepos -or $allRepos.Count -eq 0) {
            return @{
                SelectedRepo  = $null
                SelectedIndex = -1
                Cancelled     = $true
            }
        }
        
        # State variables
        $searchText = ""
        $filteredRepos = $allRepos
        $selectedIndex = 0
        $focusMode = "input"  # "input" or "list"
        $running = $true
        $cancelled = $false
        
        # If we have a current repo, try to find it in the list
        if ($null -ne $currentRepo) {
            $selectedIndex = $this.SearchService.FindRepositoryIndex($filteredRepos, $currentRepo)
        }
        
        # Calculate viewport
        $maxVisibleItems = 10
        $viewportStart = 0
        
        try {
            $this.Console.HideCursor()
            
            while ($running) {
                # Render the search UI
                $this.RenderSearchUI($searchText, $filteredRepos, $selectedIndex, $focusMode, $viewportStart, $maxVisibleItems, $allRepos.Count)
                
                # Show cursor only when in input mode
                if ($focusMode -eq "input") {
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                # Read key
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # Handle Escape - context-aware
                if ($keyCode -eq [Constants]::KEY_ESCAPE) {
                    if ($focusMode -eq "list") {
                        # Return to input
                        $focusMode = "input"
                    } else {
                        # Exit search
                        $running = $false
                        $cancelled = $true
                    }
                    continue
                }
                
                # Handle Enter - select current item
                if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($filteredRepos.Count -gt 0) {
                        $running = $false
                    }
                    continue
                }
                
                # Handle Tab - toggle focus
                if ($keyCode -eq [Constants]::KEY_TAB) {
                    if ($focusMode -eq "input" -and $filteredRepos.Count -gt 0) {
                        $focusMode = "list"
                    } else {
                        $focusMode = "input"
                    }
                    continue
                }
                
                # Handle navigation
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "input" -and $filteredRepos.Count -gt 0) {
                        # Move from input to list
                        $focusMode = "list"
                    } elseif ($focusMode -eq "list") {
                        # Navigate down in list
                        if ($selectedIndex -lt ($filteredRepos.Count - 1)) {
                            $selectedIndex++
                            # Adjust viewport
                            if ($selectedIndex -ge ($viewportStart + $maxVisibleItems)) {
                                $viewportStart = $selectedIndex - $maxVisibleItems + 1
                            }
                        } else {
                            # Wrap to top
                            $selectedIndex = 0
                            $viewportStart = 0
                        }
                    }
                    continue
                }
                
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list") {
                        if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            # Adjust viewport
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                        } else {
                            # Move back to input when at top
                            $focusMode = "input"
                        }
                    }
                    continue
                }
                
                # Handle text input (only in input mode)
                if ($focusMode -eq "input") {
                    # Backspace
                    if ($keyCode -eq [Constants]::KEY_BACKSPACE) {
                        if ($searchText.Length -gt 0) {
                            $searchText = $searchText.Substring(0, $searchText.Length - 1)
                            $filteredRepos = $this.SearchService.FilterRepositories($allRepos, $searchText)
                            $selectedIndex = 0
                            $viewportStart = 0
                        }
                        continue
                    }
                    
                    # Regular character input
                    if ($keyChar -and $keyChar -match '[\w\s\-_\.]') {
                        $searchText += $keyChar
                        $filteredRepos = $this.SearchService.FilterRepositories($allRepos, $searchText)
                        $selectedIndex = 0
                        $viewportStart = 0
                        continue
                    }
                }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        # Prepare result
        $selectedRepo = $null
        $originalIndex = -1
        
        if (-not $cancelled -and $filteredRepos.Count -gt 0 -and $selectedIndex -lt $filteredRepos.Count) {
            $selectedRepo = $filteredRepos[$selectedIndex]
            $originalIndex = $this.SearchService.FindOriginalIndex($allRepos, $selectedRepo)
        }
        
        return @{
            SelectedRepo  = $selectedRepo
            SelectedIndex = $originalIndex
            Cancelled     = $cancelled
        }
    }
    
    <#
    .SYNOPSIS
        Renders the complete search UI
    #>
    hidden [void] RenderSearchUI([string]$searchText, [array]$filteredRepos, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$maxVisible, [int]$totalCount) {
        $this.Console.ClearScreen()
        
        # Header
        $title = $this.GetLoc("Search.Title", "SEARCH REPOSITORIES")
        $this.Renderer.RenderHeader($title)
        $this.Console.NewLine()
        
        # Search input field
        $this.RenderSearchInput($searchText, ($focusMode -eq "input"))
        $this.Console.NewLine()
        
        # Results count
        $resultCount = $filteredRepos.Count
        $countText = $this.GetLoc("Search.ResultCount", "{0} of {1} repositories") -f $resultCount, $totalCount
        $this.Console.WriteLineColored("  $countText", [Constants]::ColorHint)
        $this.Console.NewLine()
        
        # Separator
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Results list
        if ($resultCount -eq 0) {
            $noResults = $this.GetLoc("Search.NoResults", "No repositories found")
            $this.Console.NewLine()
            $this.Console.WriteLineColored("  $noResults", [Constants]::ColorWarning)
            $this.Console.NewLine()
        } else {
            $this.RenderResultsList($filteredRepos, $selectedIndex, $focusMode, $viewportStart, $maxVisible)
        }
        
        # Footer hints
        $this.Console.NewLine()
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.RenderHints($focusMode)
    }
    
    <#
    .SYNOPSIS
        Renders the search input field
    #>
    hidden [void] RenderSearchInput([string]$searchText, [bool]$hasFocus) {
        $label = $this.GetLoc("Search.Label", "Search")
        $placeholder = $this.GetLoc("Search.Placeholder", "Type to filter...")
        
        $focusIndicator = if ($hasFocus) { ">" } else { " " }
        $inputColor = if ($hasFocus) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$label`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $this.Console.WriteLineColored($placeholder, [Constants]::ColorHint)
        } else {
            $this.Console.WriteLineColored($searchText, [Constants]::ColorValue)
        }
    }
    
    <#
    .SYNOPSIS
        Renders the filtered results list with viewport support
    #>
    hidden [void] RenderResultsList([array]$repos, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$maxVisible) {
        $listHasFocus = ($focusMode -eq "list")
        $endIndex = [Math]::Min($viewportStart + $maxVisible, $repos.Count)
        
        # Show scroll indicator if not at top
        if ($viewportStart -gt 0) {
            $this.Console.WriteLineColored("    $([char]0x2191) more above", [Constants]::ColorHint)
        } else {
            $this.Console.NewLine()
        }
        
        for ($i = $viewportStart; $i -lt $endIndex; $i++) {
            $repo = $repos[$i]
            $isSelected = ($i -eq $selectedIndex)
            
            # Determine prefix and colors
            $prefix = if ($isSelected -and $listHasFocus) { ">" } else { " " }
            
            if ($isSelected -and $listHasFocus) {
                $nameColor = [Constants]::ColorSelected
            } else {
                $nameColor = [Constants]::ColorMenuText
            }
            
            # Build display text
            $displayText = $repo.Name
            
            # Add alias if exists
            if ($repo.HasAlias -and $null -ne $repo.AliasInfo) {
                $aliasColor = $repo.AliasInfo.Color
                $aliasText = " [$($repo.AliasInfo.Alias)]"
                
                $this.Console.WriteColored("  $prefix ", $nameColor)
                $this.Console.WriteColored($displayText, $nameColor)
                $this.Console.WriteLineColored($aliasText, $aliasColor)
            } else {
                $this.Console.WriteLineColored("  $prefix $displayText", $nameColor)
            }
            
            # Add favorite indicator
            if ($repo.IsFavorite) {
                # Already rendered, just note it's a favorite
            }
        }
        
        # Show scroll indicator if more items below
        if ($endIndex -lt $repos.Count) {
            $remaining = $repos.Count - $endIndex
            $moreText = "    $(([char]0x2193)) $remaining more below"
            $this.Console.WriteLineColored($moreText, [Constants]::ColorHint)
        } else {
            $this.Console.NewLine()
        }
    }
    
    <#
    .SYNOPSIS
        Renders context-aware keyboard hints
    #>
    hidden [void] RenderHints([string]$focusMode) {
        if ($focusMode -eq "input") {
            $hint1 = $this.GetLoc("Search.Hint.Input", "Type to filter | Down/Tab=Go to list | Esc=Close")
            $this.Console.WriteLineColored("  $hint1", [Constants]::ColorHint)
        } else {
            $hint2 = $this.GetLoc("Search.Hint.List", "Up/Down=Navigate | Enter=Open | Up(top)/Tab=Back to search | Esc=Close")
            $this.Console.WriteLineColored("  $hint2", [Constants]::ColorHint)
        }
    }
}
