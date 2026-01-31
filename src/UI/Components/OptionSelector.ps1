class OptionSelector : ConsoleView {
    [IUIRenderer] $Renderer
    [ViewportManager] $Viewport
    
    OptionSelector([ConsoleHelper]$console, [IUIRenderer]$renderer) : base($console) {
        $this.Renderer = $renderer
        $this.Viewport = [ViewportManager]::new()
    }
    
    # ═══════════════════════════════════════════════════════════════════════════
    # NEW: Main entry point using SelectionOptions (recommended)
    # ═══════════════════════════════════════════════════════════════════════════
    [object] Show([SelectionOptions]$config) {
        if ($config.Options.Count -eq 0) {
            return $null
        }
        
        $descColor = if ($config.DescriptionColor -eq 0) { [Constants]::ColorWarning } else { $config.DescriptionColor }
        
        # Initialize selection index from config
        $initialIndex = 0
        for ($i = 0; $i -lt $config.Options.Count; $i++) {
            if ($config.Options[$i].Value -eq $config.CurrentValue) {
                $initialIndex = $i
                break
            }
        }
        
        $running = $true
        $result = $null
        
        try {
            $this.Console.HideCursor()
            if ($config.ClearScreen) {
                $this.Console.ClearScreen()
            }
            $this.Renderer.RenderHeader($config.Title)
            $preferences = $this.Renderer.PreferencesService.LoadPreferences()
            $showHeaders = if ($preferences.display.PSObject.Properties.Name -contains 'showHeaders') { $preferences.display.showHeaders } else { $true }
            if (-not $showHeaders) {
                $this.WriteLineColored("  $($config.Title)", [Constants]::ColorHighlight)
                $this.Console.WriteSeparator("-", [Constants]::UIWidth, [Constants]::ColorSeparator)
            }
            $this.NewLine()
            if (-not [string]::IsNullOrWhiteSpace($config.Description)) {
                $this.WriteLineColored("  $($config.Description)", $descColor)
                $this.NewLine()
            }
            
            $listStartTop = $this.Console.GetCursorTop()
            $reservedFooter = 6
            
            # Initial Initialize of Viewport
            # Use max page size logic here or just a safe default until the loop
            $this.Viewport.Initialize($config.Options.Count, 10, $initialIndex)
            
            while ($running) {
                # Recalculate page size dynamically
                $pageSize = $this.CalculatePageSize($config.Options.Count, $listStartTop, $reservedFooter)
                
                # Check if page size changed or ensures visibility
                if ($pageSize -ne $this.Viewport.PageSize) {
                    $this.Viewport.SetPageSize($pageSize)
                }
                # Ensure viewport is correct (defensive)
                $this.Viewport.EnsureSelectedVisible()
                
                $viewportStart = $this.Viewport.ViewportStart
                $selectedIndex = $this.Viewport.SelectedIndex
                
                $this.Console.SetCursorPosition(0, $listStartTop)
                
                # Render Loop using Viewport
                for ($i = 0; $i -lt $pageSize; $i++) {
                    $optionIndex = $viewportStart + $i
                    
                    if ($optionIndex -lt $config.Options.Count) {
                        $option = $config.Options[$optionIndex]
                        $isSelected = ($optionIndex -eq $selectedIndex)
                        $prefix = if ($isSelected) { ">" } else { " " }
                        
                        if ($null -ne $config.OnRenderItem) {
                            & $config.OnRenderItem $option $isSelected $prefix
                        } else {
                            $color = if ($isSelected) { [Constants]::ColorSelected } else { [Constants]::ColorMenuText }
                            $currentMarkerStr = if ($config.ShowCurrentMarker -and $option.Value -eq $config.CurrentValue) { " (current)" } else { "" }
                            $displayLine = "  $prefix $($option.DisplayText)$currentMarkerStr"
                            
                            $isColorPreview = $false
                            if ($option.Value -ne 'None' -and ($option.Value -as [System.ConsoleColor])) {
                                $isColorPreview = $true
                            }
                            $this.ClearLine()
                            if ($isColorPreview) {
                                $this.WriteLineColored($displayLine, $option.Value)
                            } else {
                                $this.WriteLineColored($displayLine, $color)
                            }
                        }
                    } else {
                        # Clear empty lines if any
                        $this.ClearLine()
                    }
                }
                
                if ($null -ne $config.OnSelectionChanged) {
                    & $config.OnSelectionChanged $config.Options[$selectedIndex]
                }

                # Footer
                $this.NewLine()
                $this.ClearLine()
                $this.WriteLineColored("  $($config.CancelText)", [Constants]::ColorHint)
                $this.NewLine()
                $this.NewLine()
                $this.ClearLine()
                $this.WriteLineColored("  Use Arrows to navigate | Enter to select | Q/Esc to cancel", [Constants]::ColorHint)
                
                $key = $this.Console.ReadKey()
                switch ($key.VirtualKeyCode) {
                    ([Constants]::KEY_UP_ARROW) {
                        $this.Viewport.MoveUp()
                    }
                    ([Constants]::KEY_DOWN_ARROW) {
                        $this.Viewport.MoveDown()
                    }
                    ([Constants]::KEY_ENTER) {
                        $result = $config.Options[$this.Viewport.SelectedIndex].Value
                        $running = $false
                    }
                    ([Constants]::KEY_Q) { $running = $false }
                    ([Constants]::KEY_ESC) { $running = $false }
                    ([Constants]::KEY_HOME) { $this.Viewport.MoveToStart() }
                    ([Constants]::KEY_END) { $this.Viewport.MoveToEnd() }
                }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        return $result
    }

    [bool] SelectYesNo([string]$question, [object]$localizationService, [bool]$clearScreen = $true) {
        $yesText = "Yes"
        $noText = "No"
        $cancelText = "Cancel"
        if ($null -ne $localizationService) {
            $yesText = $localizationService.Get("Prompt.Yes")
            $noText = $localizationService.Get("Prompt.No")
            $cancelText = $localizationService.Get("Prompt.Cancel")
        }
        $config = [SelectionOptions]::new()
        $config.Title = $question
        $config.Options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        $config.CancelText = $cancelText
        $config.ShowCurrentMarker = $false
        $config.ClearScreen = $clearScreen
        $result = $this.Show($config)
        if ($null -eq $result) { return $false }
        return $result
    }
    [bool] SelectYesNo([string]$question) {
        return $this.SelectYesNo($question, $null, $true)
    }
    [bool] SelectYesNo([string]$question, [bool]$clearScreen) {
        return $this.SelectYesNo($question, $null, $clearScreen)
    }
}
