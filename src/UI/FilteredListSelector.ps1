<#
.SYNOPSIS
    FilteredListSelector - Generic interactive selector with filtering
    
.DESCRIPTION
    Reuses patterns from SearchView but for generic string lists.
    - SRP: Only responsible for rendering list and handling selection input
    - DIP: Depends on ConsoleHelper, UIRenderer
#>

class FilteredListSelector {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [WindowSizeCalculator] $WindowCalculator
    
    # Layout constants
    [int] $HeaderLines = 3
    [int] $SearchInputLines = 3
    [int] $FooterLines = 4
    
    FilteredListSelector([ConsoleHelper]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.WindowCalculator = [WindowSizeCalculator]::new()
    }
    
    hidden [int] CalculatePageSize() {
        $reservedLines = $this.HeaderLines + $this.SearchInputLines + $this.FooterLines + 2
        $windowHeight = $this.WindowCalculator.GetWindowHeight()
        $available = $windowHeight - $reservedLines
        
        if ($available -lt 3) { return 3 }
        if ($available -gt 20) { return 20 }
        return $available
    }
    
    [string] ShowSelection([string]$title, [string[]]$items, [string]$prompt) {
        if ($null -eq $items -or $items.Count -eq 0) {
            return $null
        }
        
        $searchText = ""
        $filteredItems = $items
        $selectedIndex = 0
        $focusMode = "input" 
        $running = $true
        $viewportStart = 0
        $pageSize = $this.CalculatePageSize()
        $result = $null
        
        try {
            $this.Console.HideCursor()
            
            # Initial Render
            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt)
            
            while ($running) {
                 if ($focusMode -eq "input") {
                    $cursorX = 4 + $prompt.Length + 2 + $searchText.Length
                    $this.Console.SetCursorPosition($cursorX, 3)
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # Esc
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq "list") {
                        $focusMode = "input"
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt)
                    } else {
                        $running = $false
                    }
                    continue
                }
                
                # Enter
                 if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($filteredItems.Count -gt 0) {
                        $result = $filteredItems[$selectedIndex]
                        $running = $false
                    }
                    continue
                }
                
                # Tab
                if ($keyCode -eq [Constants]::KEY_TAB) {
                    if ($focusMode -eq "input" -and $filteredItems.Count -gt 0) {
                        $focusMode = "list"
                    } else {
                        $focusMode = "input"
                    }
                    $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt)
                    continue
                }
                
                # Arrows
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "input" -and $filteredItems.Count -gt 0) {
                        $focusMode = "list"
                        $selectedIndex = 0
                        $viewportStart = 0
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt)
                    } elseif ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        if ($selectedIndex -lt ($filteredItems.Count - 1)) {
                            $selectedIndex++
                            if ($selectedIndex -ge ($viewportStart + $pageSize)) {
                                $viewportStart = $selectedIndex - $pageSize + 1
                            }
                        } else {
                            $selectedIndex = 0
                            $viewportStart = 0
                        }
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize)
                    }
                    continue
                }
                
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                         if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                        } else {
                            $focusMode = "input"
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt)
                            continue
                        }
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize)
                    }
                    continue
                }
                
                # Input
                 if ($focusMode -eq "input") {
                    $needsUpdate = $false
                    if ($keyCode -eq [Constants]::KEY_BACKSPACE) {
                        if ($searchText.Length -gt 0) {
                            $searchText = $searchText.Substring(0, $searchText.Length - 1)
                            $needsUpdate = $true
                        }
                    } elseif ($keyChar -match '[a-zA-Z0-9\s\-\._\/]') {
                        $searchText += $keyChar
                        $needsUpdate = $true
                    }
                    
                    if ($needsUpdate) {
                        $lowerSearch = $searchText.ToLower()
                        $filteredItems = @($items | Where-Object { $_.ToLower().Contains($lowerSearch) })
                        $selectedIndex = 0
                        $viewportStart = 0
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt)
                    }
                 }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        return $result
    }
    
    hidden [void] RenderFull([string]$title, [string]$searchText, [array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$totalCount, [string]$prompt) {
        $this.Console.HideCursor()
        $this.Console.ClearScreen()
        
        $this.Renderer.RenderHeader($title)
        
        # Search Input
        $focusIndicator = if ($focusMode -eq "input") { ">" } else { " " }
        $inputColor = if ($focusMode -eq "input") { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$prompt`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $this.Console.WriteLineColored("Type to filter...", [Constants]::ColorHint)
        } else {
            $this.Console.WriteLineColored($searchText, [Constants]::ColorValue)
        }
        $this.Console.NewLine()
        
        $countText = "{0} of {1} items" -f $items.Count, $totalCount
        $this.Console.WriteLineColored("  $countText", [Constants]::ColorHint)
        $this.Console.NewLine()
        
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        $this.RenderList($items, $selectedIndex, $focusMode, $viewportStart, $pageSize)
        
        # Footer
        $listEnd = $this.HeaderLines + $this.SearchInputLines + 2 + 1 + $pageSize
        $this.Console.SetCursorPosition(0, $listEnd)
        $this.Console.WriteSeparator("=", [Constants]::UIWidth, [Constants]::ColorSeparator)
        $this.Console.WriteLineColored("  Enter to select | Esc to cancel", [Constants]::ColorHint)
    }
    
    hidden [void] RenderList([array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize) {
        $startLine = $this.HeaderLines + $this.SearchInputLines + 2 + 1 # Header + Input + Count + Sep
        
        for ($i = 0; $i -lt $pageSize; $i++) {
            $this.Console.SetCursorPosition(0, $startLine + $i)
            $this.Console.ClearCurrentLine()
            
            $itemIndex = $viewportStart + $i
            if ($itemIndex -lt $items.Count) {
                $item = $items[$itemIndex]
                $isSelected = ($itemIndex -eq $selectedIndex) -and ($focusMode -eq "list")
                
                $prefix = if ($isSelected) { ">" } else { " " }
                $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                
                $this.Console.WriteColored("  $prefix ", $color)
                $this.Console.WriteLineColored($item, $color)
            }
        }
    }
}
