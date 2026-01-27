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
    [FilteredListRenderer] $ListRenderer # New dependency
    
    # Layout constants
    [int] $HeaderLines = 3
    
    # State persistence for header navigation
    [int] $LastHeaderIndex = 0

    FilteredListSelector([ConsoleHelper]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.WindowCalculator = [WindowSizeCalculator]::new()
        # Instantiate renderer internally using injected dependencies
        $this.ListRenderer = [FilteredListRenderer]::new($console, $renderer)
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
        $showHeaders = $this.Renderer.ShouldShowHeaders()
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
                     elseif ($initialIndex -ge 0) { [Constants]::FocusList } 
                     else { [Constants]::FocusInput }
        
        $running = $true
        $result = $null
        
        try {
            $this.Console.HideCursor()
            
            # Initial Render
            $this.ListRenderer.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $this.HeaderLines, $items.Count, $prompt, $headerOptions, $true, $currentItem, $currentMarker, $statusMessage, $statusColor)
            
            while ($running) {
                if ($focusMode -eq [Constants]::FocusInput) {
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
                
                # Esc
                if ($keyCode -eq [Constants]::KEY_ESCAPE -or $keyCode -eq [Constants]::KEY_ESC) {
                    if ($focusMode -eq [Constants]::FocusList -or $focusMode -eq [Constants]::FocusHeader) {
                        $focusMode = [Constants]::FocusInput
                        # Partial update - header (if any), input, and list
                        if ($headerOptions.Count -gt 0) {
                            $this.ListRenderer.UpdateHeaderOptions($headerOptions, $headerIndex, $focusMode, $this.HeaderLines)
                        }
                        $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    } else {
                        $running = $false
                    }
                    continue
                }
                
                # Enter
                if ($keyCode -eq [Constants]::KEY_ENTER) {
                    if ($focusMode -eq [Constants]::FocusList -and $filteredItems.Count -gt 0) {
                        $result = @{ Type = "Item"; Value = $filteredItems[$selectedIndex]; Index = $selectedIndex }
                        $running = $false
                    }
                    elseif ($focusMode -eq [Constants]::FocusHeader -and $headerOptions.Count -gt 0) {
                         $this.LastHeaderIndex = $headerIndex # Persist choice
                         $result = @{ Type = "Header"; Value = $headerOptions[$headerIndex] }
                         $running = $false
                    }
                }
                
                # Tab (Cycle Input <-> List)
                if ($keyCode -eq [Constants]::KEY_TAB) {
                    if ($focusMode -eq [Constants]::FocusInput) {
                        if ($filteredItems.Count -gt 0) { 
                            $focusMode = [Constants]::FocusList 
                            # Partial update - only input line and list
                            $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                            $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                        }
                        # Default is stay in input if list empty
                    } 
                    elseif ($focusMode -eq [Constants]::FocusList) {
                        $focusMode = [Constants]::FocusInput
                        # Partial update - only input line and list
                        $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    elseif ($focusMode -eq [Constants]::FocusHeader) {
                        $focusMode = [Constants]::FocusInput
                        # Partial update - header options, input line and list
                        $this.ListRenderer.UpdateHeaderOptions($headerOptions, $headerIndex, $focusMode, $this.HeaderLines)
                        $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    
                    continue
                }
                
                # Left / Right (Header Navigation)
                if ($focusMode -eq [Constants]::FocusHeader) {
                    if ($keyCode -eq [Constants]::KEY_LEFT_ARROW) {
                        if ($headerIndex -gt 0) {
                            $headerIndex--
                            $this.LastHeaderIndex = $headerIndex
                            # Partial update - only header options line
                            $this.ListRenderer.UpdateHeaderOptions($headerOptions, $headerIndex, $focusMode, $this.HeaderLines)
                        }
                        continue
                    }
                     if ($keyCode -eq [Constants]::KEY_RIGHT_ARROW) {
                        if ($headerIndex -lt ($headerOptions.Count - 1)) {
                            $headerIndex++
                            $this.LastHeaderIndex = $headerIndex
                            # Partial update - only header options line
                            $this.ListRenderer.UpdateHeaderOptions($headerOptions, $headerIndex, $focusMode, $this.HeaderLines)
                        }
                        continue
                    }
                }
                
                # Down Arrow
                if ($keyCode -eq [Constants]::KEY_DOWN_ARROW) {
                    if ($focusMode -eq [Constants]::FocusHeader) {
                        # Down goes to input - partial update
                        $this.LastHeaderIndex = $headerIndex # Remember
                        $focusMode = [Constants]::FocusInput
                        $this.ListRenderer.UpdateHeaderOptions($headerOptions, $headerIndex, $focusMode, $this.HeaderLines)
                        $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    elseif ($focusMode -eq [Constants]::FocusInput) {
                        if ($filteredItems.Count -gt 0) {
                            $focusMode = [Constants]::FocusList
                            $selectedIndex = 0
                            $viewportStart = 0
                            # Partial update - input and list
                            $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                            $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                        }
                    }
                    elseif ($focusMode -eq [Constants]::FocusList -and $filteredItems.Count -gt 0) {
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
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    continue
                }
                
                # Up Arrow
                if ($keyCode -eq [Constants]::KEY_UP_ARROW) {
                    if ($focusMode -eq [Constants]::FocusList) {
                         if ($selectedIndex -gt 0) {
                            $selectedIndex--
                            if ($selectedIndex -lt $viewportStart) {
                                $viewportStart = $selectedIndex
                            }
                            # Pass total items count to RenderList
                            $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                        } else {
                            # Go to Input - partial update
                            $focusMode = [Constants]::FocusInput
                            $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                            $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                        }
                    }
                    elseif ($focusMode -eq [Constants]::FocusInput) {
                        if ($headerOptions.Count -gt 0) {
                            $focusMode = [Constants]::FocusHeader
                            # Restore last header index
                            $headerIndex = if ($this.LastHeaderIndex -lt $headerOptions.Count) { $this.LastHeaderIndex } else { 0 }
                            # Partial update - header and input
                            $this.ListRenderer.UpdateHeaderOptions($headerOptions, $headerIndex, $focusMode, $this.HeaderLines)
                            $this.ListRenderer.UpdateSearchInput($searchText, $focusMode, $this.HeaderLines, $headerOptions.Count, $prompt)
                        }
                    }
                    continue
                }
                
                # Home
                if ($keyCode -eq [Constants]::KEY_HOME) {
                    if ($focusMode -eq [Constants]::FocusList -and $filteredItems.Count -gt 0) {
                        $selectedIndex = 0
                        $viewportStart = 0
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    continue
                }
                
                # End
                if ($keyCode -eq [Constants]::KEY_END) {
                    if ($focusMode -eq [Constants]::FocusList -and $filteredItems.Count -gt 0) {
                        $selectedIndex = $filteredItems.Count - 1
                        if ($selectedIndex -ge $pageSize) {
                            $viewportStart = $selectedIndex - $pageSize + 1
                        } else {
                            $viewportStart = 0
                        }
                        $this.ListRenderer.RenderList($filteredItems, $selectedIndex, $focusMode, $viewportStart, $pageSize, $headerOptions.Count, $this.HeaderLines, $items.Count, $currentItem, $currentMarker, $statusMessage, $statusColor)
                    }
                    continue
                }
                
                # Input
                 if ($focusMode -eq [Constants]::FocusInput) {
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
                        $this.ListRenderer.RenderFull($title, $searchText, $filteredItems, $selectedIndex, $headerIndex, $focusMode, $viewportStart, $pageSize, $this.HeaderLines, $items.Count, $prompt, $headerOptions, $false, $currentItem, $currentMarker, $null, $statusColor)
                    }
                 }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        
        return $result
    }
}
