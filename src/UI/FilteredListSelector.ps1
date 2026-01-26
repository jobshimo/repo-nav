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
    
    # State persistence for header navigation
    [int] $LastHeaderIndex = 0

    FilteredListSelector([ConsoleHelper]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.WindowCalculator = [WindowSizeCalculator]::new()
    }
    
    hidden [int] CalculatePageSize([int]$headerOptionCount) {
        # Reserved: 
        # Header($this.HeaderLines) 
        # HeaderOptions (1 line horizontal if > 0)
        # Input (1)
        # Count (1)
        # Separator (1)
        # Footer: Sep(1) + Info(1) + Hints(1) + Sep(1) = 4
        
        $optsHeight = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        
        $footerLines = 4
        $reservedLines = $this.HeaderLines + $optsHeight + 1 + 1 + 1 + $footerLines
        
        $windowHeight = $this.WindowCalculator.GetWindowHeight()
        $available = $windowHeight - $reservedLines
        
        # User requirement: At least 1 item must be visible
        if ($available -lt 1) { return 1 }
        if ($available -gt 25) { return 25 }
        return $available
    }
    
    # Returns a hashtable:
    # @{ Type = "Item"; Value = "SelectedString" }
    # @{ Type = "Header"; Value = "HeaderOption" }
    # $null if cancelled
    [object] ShowSelection([string]$title, [string[]]$items, [hashtable]$options) {
        if ($null -eq $items -or $items.Count -eq 0) {
            return $null
        }
        
        # Check Header Preference
        $preferences = $this.Renderer.PreferencesService.LoadPreferences()
        $showHeaders = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
        $this.HeaderLines = if ($showHeaders) { 3 } else { 0 }
        
        # Unpack options with defaults
        $prompt = if ($options.ContainsKey('Prompt')) { $options['Prompt'] } else { "Filter" }
        $headerOptions = if ($options.ContainsKey('HeaderOptions')) { $options['HeaderOptions'] } else { @() }
        $currentItem = if ($options.ContainsKey('CurrentItem')) { $options['CurrentItem'] } else { $null }
        $currentMarker = if ($options.ContainsKey('CurrentMarker')) { $options['CurrentMarker'] } else { "(current)" }
        $initialIndex = if ($options.ContainsKey('InitialIndex')) { [int]$options['InitialIndex'] } else { 0 }
        $statusMessage = if ($options.ContainsKey('StatusMessage')) { $options['StatusMessage'] } else { $null }
        $statusColor = if ($options.ContainsKey('StatusColor')) { $options['StatusColor'] } else { [ConsoleColor]::Gray }
        
        $searchText = ""
        $filteredItems = $items
        
        # Initialize selection and viewport
        $selectedIndex = if ($initialIndex -ge 0 -and $initialIndex -lt $items.Count) { $initialIndex } else { 0 }
        $pageSize = $this.CalculatePageSize($headerOptions.Count)
        
        $viewportStart = 0
        if ($selectedIndex -ge $pageSize) {
            $viewportStart = $selectedIndex - $pageSize + 1
        }
        
        # Restore last header index or default to 0
        $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { 0 }
        
        # Focus modes: "header", "input", "list"
        $desiredFocus = if ($options.ContainsKey('InitialFocus')) { $options['InitialFocus'] } else { $null }
        $focusMode = if ($desiredFocus) { $desiredFocus }
                     elseif ($initialIndex -ge 0) { "list" } 
                     else { "input" }
        
        $running = $true
        $result = $null
        
        try {
            $this.Console.HideCursor()
            
            # Initial Render - Clear screen once
            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $true, $currentItem, $currentMarker, $statusMessage, $statusColor)
            
            # ... Input handling loop omitted for brevity in diff, assumed mostly same logic but with updated Render calls ... 
            # NOTE: We need to replace the whole method to ensure variable scope and logic flow is correct, 
            # but for replace_file_content we must match existing content. 
            # Since the logic inside the loop uses RenderFull and RenderList, we need to make sure those methods
            # are updated to match the new signatures if we changed them.
            # I will only replace the top part and helper methods, and assumes the loop logic calls methods that I update below.
            
            while ($running) {
                if ($focusMode -eq "input") {
                    # Calculate cursor X: indent (4 for "  > ") + prompt + ": " (2) + text
                    $cursorX = 4 + $prompt.Length + 2 + $searchText.Length
                    # Calculate cursor Y: 
                    # Header($this.HeaderLines) + HeaderOptions(1 if any)
                    $hLines = if ($headerOptions.Count -gt 0) { 1 } else { 0 }
                    $cursorY = $this.HeaderLines + $hLines
                    
                    $this.Console.SetCursorPosition($cursorX, $cursorY)
                    $this.Console.ShowCursor()
                } else {
                    $this.Console.HideCursor()
                }
                
                $key = $this.Console.ReadKey()
                $keyCode = $key.VirtualKeyCode
                $keyChar = $key.Character
                
                # ... Event loop logic ...
                # Esc
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq "list" -or $focusMode -eq "header") {
                        $focusMode = "input"
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    } else {
                        $running = $false
                    }
                    continue
                }
                
                # Enter
                if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        $result = @{ Type = "Item"; Value = $filteredItems[$selectedIndex]; Index = $selectedIndex }
                        $running = $false
                    }
                    elseif ($focusMode -eq "header" -and $headerOptions.Count -gt 0) {
                         $this.LastHeaderIndex = $headerIndex # Persist choice
                         $result = @{ Type = "Header"; Value = $headerOptions[$headerIndex] }
                         $running = $false
                    }
                    continue
                }
                
                # Tab (Cycle Input -> List -> Header -> Input ?)
                if ($keyCode -eq [Constants]::KEY_TAB) {
                    if ($focusMode -eq "input") {
                        if ($filteredItems.Count -gt 0) { $focusMode = "list" }
                        elseif ($headerOptions.Count -gt 0) { $focusMode = "header" }
                    } 
                    elseif ($focusMode -eq "list") {
                        if ($headerOptions.Count -gt 0) { $focusMode = "header" }
                        else { $focusMode = "input" }
                    }
                    elseif ($focusMode -eq "header") {
                        $focusMode = "input"
                    }
                    
                    $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    continue
                }
                
                # Left / Right (Header Navigation)
                if ($focusMode -eq "header") {
                    if ($keyCode -eq [Constants]::KEY_LEFT_ARROW) {
                        if ($headerIndex -gt 0) {
                            $headerIndex--
                            $this.LastHeaderIndex = $headerIndex
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                        continue
                    }
                     if ($keyCode -eq [Constants]::KEY_RIGHT_ARROW) {
                        if ($headerIndex -lt ($headerOptions.Count - 1)) {
                            $headerIndex++
                            $this.LastHeaderIndex = $headerIndex
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                        continue
                    }
                }
                
                # Down Arrow
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq "header") {
                        # Down goes to input
                        $this.LastHeaderIndex = $headerIndex # Remember
                        $focusMode = "input"
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    }
                    elseif ($focusMode -eq "input") {
                        if ($filteredItems.Count -gt 0) {
                            $focusMode = "list"
                            $selectedIndex = 0
                            $viewportStart = 0
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                    }
                    elseif ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        if ($selectedIndex -lt ($filteredItems.Count - 1)) {
                            $selectedIndex++
                            if ($selectedIndex -ge ($viewportStart + $pageSize)) {
                                $viewportStart = $selectedIndex - $pageSize + 1
                            }
                        } else {
                            $selectedIndex = 0
                            $viewportStart = 0
                        }
                        # Pass total items count to RenderList
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    continue
                }
                
                # Up Arrow
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq "list") {
                         if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                            # Pass total items count to RenderList
                            $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                        } else {
                            # Go to Input
                            $focusMode = "input"
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                    }
                    elseif ($focusMode -eq "input") {
                        if ($headerOptions.Count -gt 0) {
                            $focusMode = "header"
                            # Restore last header index
                            $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { 0 }
                            
                            $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                        }
                    }
                    continue
                }
                
                # Home
                if ($keyCode -eq [Constants]::KEY_HOME) {
                    if ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        $selectedIndex = 0
                        $viewportStart = 0
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    continue
                }
                
                # End
                if ($keyCode -eq [Constants]::KEY_END) {
                    if ($focusMode -eq "list" -and $filteredItems.Count -gt 0) {
                        $selectedIndex = $filteredItems.Count - 1
                        if ($selectedIndex -ge $pageSize) {
                            $viewportStart = $selectedIndex - $pageSize + 1
                        } else {
                            $viewportStart = 0
                        }
                        $this.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
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
                        $this.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    }
                 }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        return $result
    }
    
    hidden [void] RenderFooter([int]$selectedIndex, [int]$filteredCount, [int]$totalCount, [string]$statusMessage, [ConsoleColor]$statusColor, [int]$footerStartLine, [bool]$clearScreen) {
        # Footer area: 4 lines
        for ($i = 0; $i -lt 4; $i++) {
            $this.Console.SetCursorPosition(0, $footerStartLine + $i)
            if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        }
        
        # 1. Separator
        $this.Console.SetCursorPosition(0, $footerStartLine)
        $sep = "=" * [Constants]::UIWidth
        $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
        
        # 2. Counts
        $this.Console.SetCursorPosition(0, $footerStartLine + 1)
        if ($filteredCount -gt 0) {
            $currentPos = $selectedIndex + 1
            $lblItem = $this.Renderer.GetLoc("UI.Label.Item", "Item")
            $lblFiltered = $this.Renderer.GetLoc("UI.Label.Filtered", "Filtered")
            $lblOf = $this.Renderer.GetLoc("UI.Label.Of", "of")
            
            $this.Console.WriteColored("  $lblItem`: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$currentPos/$filteredCount", [Constants]::ColorValue)
            $this.Console.WriteColored(" | $lblFiltered`: ", [Constants]::ColorLabel)
            $this.Console.WriteColored("$filteredCount $lblOf $totalCount", [Constants]::ColorHint)
        } else {
             $noItems = $this.Renderer.GetLoc("Search.NoItems", "No items found")
             $this.Console.WriteColored("  $noItems", [Constants]::ColorWarning)
        }
        
        # 3. Message / Hints
        $this.Console.SetCursorPosition(0, $footerStartLine + 2)
        if (-not [string]::IsNullOrEmpty($statusMessage)) {
             $this.Console.WriteColored("  $statusMessage", $statusColor)
        } else {
             $hint = $this.Renderer.GetLoc("Search.Hint.FilteredList", "$([char]0x2191)$([char]0x2193)=Navigate | Enter=Select | Esc=Cancel")
             $this.Console.WriteColored("  $hint", [Constants]::ColorHint)
        }
        
        # 4. Final Separator
        $this.Console.SetCursorPosition(0, $footerStartLine + 3)
        $this.Console.WriteColored($sep, [Constants]::ColorSeparator)
    }

    hidden [void] RenderFull([string]$title, [string]$searchText, [array]$items, [int]$selectedIndex, [int]$headerIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$totalCount, [string]$prompt, [string[]]$headerOptions, [bool]$clearScreen, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {
        $this.Console.HideCursor()
        
        if ($clearScreen) {
            $this.Console.ClearScreen()
        } else {
            $this.Console.SetCursorPosition(0, 0)
        }
        
        # ... (Header Rendering same as before) ...
        $this.Renderer.RenderHeader($title)
        
        if ($headerOptions.Count -gt 0) {
            if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
            $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
            for ($i = 0; $i -lt $headerOptions.Count; $i++) {
                 $isHeaderSelected = ($focusMode -eq "header" -and $i -eq $headerIndex)
                 $opt = $headerOptions[$i]
                 $currentOpt = if ($isHeaderSelected) { " > $opt " } else { "   $opt " }
                 $hColor = if ($isHeaderSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                 $this.Console.WriteColored($currentOpt, $hColor)
                 $this.Console.WriteColored("  ", [Constants]::ColorMenuText)
            }
            $this.Console.NewLine()
        }
        
        # Input
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $focusIndicator = if ($focusMode -eq "input") { ">" } else { " " }
        $inputColor = if ($focusMode -eq "input") { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
        $this.Console.WriteColored("  $focusIndicator ", $inputColor)
        $this.Console.WriteColored("$prompt`: ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrEmpty($searchText)) {
            $placeholder = $this.Renderer.GetLoc("Search.TypeToFilter", "Type to filter...")
            $this.Console.WriteLineColored($placeholder, [Constants]::ColorHint)
        } else {
            $this.Console.WriteLineColored($searchText, [Constants]::ColorValue)
        }
        
        # Count
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $lblOf = $this.Renderer.GetLoc("UI.Label.Of", "of")
        $lblItems = $this.Renderer.GetLoc("UI.Label.Items", "items")
        # "{0} of {1} items"
        $countText = "{0} $lblOf {1} $lblItems" -f $items.Count, $totalCount
        $this.Console.WriteLineColored("  $countText", [Constants]::ColorHint)
        
        # Separator (Before List)
        if (-not $clearScreen) { $this.Console.ClearCurrentLine() }
        $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
        
        # Render List and Footer
        $this.RenderList($items, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $totalCount, $currentItem, $currentMarker, $statusMessage, $statusColor)
    }
    
    hidden [void] RenderList([array]$items, [int]$selectedIndex, [string]$focusMode, [int]$viewportStart, [int]$pageSize, [int]$headerOptionCount, [int]$totalCount, [string]$currentItem, [string]$currentMarker, [string]$statusMessage, [ConsoleColor]$statusColor) {
        $hLines = if ($headerOptionCount -gt 0) { 1 } else { 0 }
        
        # Consistent Layout Calc:
        # Header($this.HeaderLines) + Opts(hLines) + Input(1) + Count(1) + Sep(1) = StartLine
        $startLine = $this.HeaderLines + $hLines + 1 + 1 + 1
        
        # Draw items
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
                $this.Console.WriteColored($item, $color)
                
                if ($null -ne $currentItem -and $item -eq $currentItem) {
                    $this.Console.WriteColored(" $currentMarker", [Constants]::ColorHint)
                }
            }
        }
        
        # Explicitly redraw footer every time the list updates to ensure it's not overwritten/ghosted
        $footerStart = $startLine + $pageSize
        $this.RenderFooter($selectedIndex, $items.Count, $totalCount, $statusMessage, $statusColor, $footerStart, $false)
    }
}
