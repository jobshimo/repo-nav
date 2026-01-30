class OptionSelector : ConsoleView {
    [UIRenderer] $Renderer
    OptionSelector([ConsoleHelper]$console, [object]$renderer) : base($console) {
        $this.Renderer = $renderer
    }
    
    # ═══════════════════════════════════════════════════════════════════════════
    # NEW: Main entry point using SelectionOptions (recommended)
    # ═══════════════════════════════════════════════════════════════════════════
    [object] Show([SelectionOptions]$config) {
        if ($config.Options.Count -eq 0) {
            return $null
        }
        
        $descColor = if ($config.DescriptionColor -eq 0) { [Constants]::ColorWarning } else { $config.DescriptionColor }
        $selectedIndex = 0
        for ($i = 0; $i -lt $config.Options.Count; $i++) {
            if ($config.Options[$i].Value -eq $config.CurrentValue) {
                $selectedIndex = $i
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
            $viewportStart = 0
            $reservedFooter = 6
            
            while ($running) {
                $pageSize = $this.CalculatePageSize($config.Options.Count, $listStartTop, $reservedFooter)
                $viewportStart = $this.CalculateViewportStart($selectedIndex, $viewportStart, $pageSize, $config.Options.Count)
                $this.Console.SetCursorPosition(0, $listStartTop)
                
                for ($i = 0; $i -lt $pageSize; $i++) {
                    $optionIndex = $viewportStart + $i
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
                }
                
                if ($null -ne $config.OnSelectionChanged) {
                    & $config.OnSelectionChanged $config.Options[$selectedIndex]
                }

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
                        if ($selectedIndex -gt 0) { $selectedIndex-- }
                        else { $selectedIndex = $config.Options.Count - 1 }
                    }
                    ([Constants]::KEY_DOWN_ARROW) {
                        if ($selectedIndex -lt ($config.Options.Count - 1)) { $selectedIndex++ }
                        else { $selectedIndex = 0 }
                    }
                    ([Constants]::KEY_ENTER) {
                        $result = $config.Options[$selectedIndex].Value
                        $running = $false
                    }
                    ([Constants]::KEY_Q) { $running = $false }
                    ([Constants]::KEY_ESC) { $running = $false }
                }
            }
        }
        finally {
            $this.Console.HideCursor()
        }
        return $result
    }
    
    # ═══════════════════════════════════════════════════════════════════════════
    # LEGACY: Overloads for backwards compatibility (will be deprecated)
    # ═══════════════════════════════════════════════════════════════════════════
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText) {
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Options = $options
        $config.CurrentValue = $currentValue
        $config.CancelText = $cancelText
        return $this.Show($config)
    }
    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText, [bool]$showCurrentMarker, [string]$description, [ConsoleColor]$descriptionColor, [bool]$clearScreen = $true) {
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Options = $options
        $config.CurrentValue = $currentValue
        $config.CancelText = $cancelText
        $config.ShowCurrentMarker = $showCurrentMarker
        $config.Description = $description
        $config.DescriptionColor = if ($descriptionColor -eq 0) { [Constants]::ColorWarning } else { $descriptionColor }
        $config.ClearScreen = $clearScreen
        return $this.Show($config)
    }

    [object] ShowSelection([string]$title, [array]$options, [object]$currentValue, [string]$cancelText, [bool]$showCurrentMarker, [string]$description, [ConsoleColor]$descriptionColor, [bool]$clearScreen, [scriptblock]$onSelectionChanged, [scriptblock]$onRenderItem) {
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Options = $options
        $config.CurrentValue = $currentValue
        $config.CancelText = $cancelText
        $config.ShowCurrentMarker = $showCurrentMarker
        $config.Description = $description
        $config.DescriptionColor = if ($descriptionColor -eq 0) { [Constants]::ColorWarning } else { $descriptionColor }
        $config.ClearScreen = $clearScreen
        $config.OnSelectionChanged = $onSelectionChanged
        $config.OnRenderItem = $onRenderItem
        return $this.Show($config)
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
        $options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        $result = $this.ShowSelection($question, $options, $false, $cancelText, $false, "", [Constants]::ColorWarning, $clearScreen)
        if ($null -eq $result) {
            return $false
        }
        return $result
    }
    [bool] SelectYesNo([string]$question) {
        return $this.SelectYesNo($question, $null, $true)
    }
    [bool] SelectYesNo([string]$question, [bool]$clearScreen) {
        return $this.SelectYesNo($question, $null, $clearScreen)
    }
}
