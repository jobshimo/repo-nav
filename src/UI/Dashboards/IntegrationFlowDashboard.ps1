class IntegrationFlowDashboard {
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [LocalizationService] $LocService

    # Layout Configuration
    [int] $HeaderLines = 3
    [int] $StartLine = 0
    
    # Track current input selection to minimize redraws
    [int] $LastSelectedIndex = -1

    IntegrationFlowDashboard([ConsoleHelper]$console, [UIRenderer]$renderer, [LocalizationService]$locService) {
        $this.Console = $console
        $this.Renderer = $renderer
        $this.LocService = $locService
        $this.StartLine = $this.HeaderLines + 2 # Header + Spacing
    }

    [string] GetLoc([string]$key, [string]$default) {
        return $this.LocService.Get($key, $default)
    }

    # Initial Full Render
    [void] RenderFull([IntegrationFlowModel]$model, [int]$selectedIndex) {
        $this.Console.ClearScreen()
        
        $title = $this.GetLoc("Flow.Dashboard.Title", "INTEGRATION FLOW DASHBOARD")
        $this.Renderer.RenderHeader($title)
        $this.Console.NewLine()
        
        # Helper labels
        $targetLabel = $this.GetLoc("Flow.Dashboard.Target", "TARGET (Remote)").PadRight(20)
        $nameLabel = $this.GetLoc("Flow.Dashboard.Name", "BRANCH NAME").PadRight(20)
        $sourceLabel = $this.GetLoc("Flow.Dashboard.Source", "SOURCE (Local)").PadRight(20)

        # Render items
        $this.RenderItemLine(0, $targetLabel, $model.TargetBranch, $model.TargetBranchValid, ($selectedIndex -eq 0))
        $this.RenderItemLine(1, $nameLabel, $model.NewBranchName, $model.NewBranchNameValid, ($selectedIndex -eq 1))
        $this.RenderItemLine(2, $sourceLabel, $model.SourceBranch, $model.SourceBranchValid, ($selectedIndex -eq 2))
        
        $this.Console.NewLine()
        
        # Render Actions
        $canExecute = $model.IsReadyToExecute()
        $this.RenderActions($selectedIndex, $canExecute)
        
        # Explicit position for hint to avoid overlap
        $this.Console.SetCursorPosition(0, $this.StartLine + 7)
        $this.Console.ClearCurrentLine()
        $hintText = $this.GetLoc("Flow.Dashboard.Hint", "Use Arrows to navigate | Enter to edit/select")
        $this.Console.WriteLineColored("  $hintText", [Constants]::ColorHint)
        
        $this.LastSelectedIndex = $selectedIndex
    }

    # Partial Update: Only updates lines that changed selection state
    [void] UpdateSelection([IntegrationFlowModel]$model, [int]$newIndex) {
        if ($newIndex -eq $this.LastSelectedIndex) { return }

        $oldIndex = $this.LastSelectedIndex
        $this.Console.HideCursor()

        $targetLabel = $this.GetLoc("Flow.Dashboard.Target", "TARGET (Remote)").PadRight(20)
        $nameLabel = $this.GetLoc("Flow.Dashboard.Name", "BRANCH NAME").PadRight(20)
        $sourceLabel = $this.GetLoc("Flow.Dashboard.Source", "SOURCE (Local)").PadRight(20)

        # Update Old Item (Deselect)
        if ($oldIndex -eq 0) { $this.RenderItemLine(0, $targetLabel, $model.TargetBranch, $model.TargetBranchValid, $false) }
        elseif ($oldIndex -eq 1) { $this.RenderItemLine(1, $nameLabel, $model.NewBranchName, $model.NewBranchNameValid, $false) }
        elseif ($oldIndex -eq 2) { $this.RenderItemLine(2, $sourceLabel, $model.SourceBranch, $model.SourceBranchValid, $false) }
        
        # Update New Item (Select)
        if ($newIndex -eq 0) { $this.RenderItemLine(0, $targetLabel, $model.TargetBranch, $model.TargetBranchValid, $true) }
        elseif ($newIndex -eq 1) { $this.RenderItemLine(1, $nameLabel, $model.NewBranchName, $model.NewBranchNameValid, $true) }
        elseif ($newIndex -eq 2) { $this.RenderItemLine(2, $sourceLabel, $model.SourceBranch, $model.SourceBranchValid, $true) }

        # Always re-render actions if focus moves in/out of action area
        $canExecute = $model.IsReadyToExecute()
        $this.RenderActions($newIndex, $canExecute)

        $this.LastSelectedIndex = $newIndex
        $this.Console.HideCursor() # Ensure hidden
    }
    
    hidden [void] RenderItemLine([int]$index, [string]$label, [string]$value, [bool]$isValid, [bool]$isSelected) {
        $line = $this.StartLine + $index
        # Optimization: Don't clear line, just overwrite.
        $this.Console.SetCursorPosition(0, $line)
        
        $prefix = if ($isSelected) { "  > " } else { "    " }
        $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
        
        # Label turns Green if selected
        $labelColor = if ($isSelected) { [ConsoleColor]::Green } else { [Constants]::ColorLabel }
        $this.Console.WriteColored("$label : ", $labelColor)
        
        if ([string]::IsNullOrWhiteSpace($value)) {
            $notSel = $this.GetLoc("Flow.Dashboard.NotSelected", "<Not Selected>")
            $this.Console.WriteColored($notSel, [Constants]::ColorHint)
            # Pad remaining to clear potential old long text
            $this.Console.WriteColored(" " * 20, [Constants]::ColorHint) 
        } else {
            $color = if ($isValid) { [Constants]::ColorValue } else { [Constants]::ColorWarning }
            $this.Console.WriteColored($value, $color)
            # Pad remaining to clear potential old long text
            $this.Console.WriteColored(" " * 20, [Constants]::ColorHint)
        }
    }

    hidden [void] RenderActions([int]$selectedIndex, [bool]$canExecute) {
        $actionLineStart = $this.StartLine + 4
        
        $executeText = "[ " + $this.GetLoc("Flow.Dashboard.Execute", "EXECUTE INTEGRATION") + " ]"
        $exitText = "[ " + $this.GetLoc("Flow.Dashboard.Exit", "Exit / Cancel") + " ]"
        
        # Execute Button
        $this.Console.SetCursorPosition(0, $actionLineStart)
        $this.Console.ClearCurrentLine()
        if ($canExecute) {
            $isSel = ($selectedIndex -eq 3)
            $prefix = if ($isSel) { "  > " } else { "    " }
            $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
            $color = if ($isSel) { [ConsoleColor]::Green } else { [Constants]::ColorSuccess }
            $this.Console.WriteLineColored($executeText, $color)
        } else {
            # Placeholder to keep layout stable
             $this.Console.WriteLineColored("", [Constants]::ColorHint)
        }

        # Exit Button
        $this.Console.SetCursorPosition(0, $actionLineStart + 1)
        $this.Console.ClearCurrentLine()
        
        # Index logic: If canExecute, Exit is 4. If not, Exit is 3.
        # But for valid navigation, we map logical index to visual
        $isSelExit = ($canExecute -and $selectedIndex -eq 4) -or (-not $canExecute -and $selectedIndex -eq 3)
        
        $prefixExit = if ($isSelExit) { "  > " } else { "    " }
        $this.Console.WriteColored($prefixExit, [Constants]::ColorHighlight)
        $colorExit = if ($isSelExit) { [ConsoleColor]::Green } else { [Constants]::ColorHint }
        $this.Console.WriteLineColored($exitText, $colorExit)
    }

    [void] UpdateValue([IntegrationFlowModel]$model, [int]$index) {
         # Force update of a specific line after editing
         $targetLabel = $this.GetLoc("Flow.Dashboard.Target", "TARGET (Remote)").PadRight(20)
         $nameLabel = $this.GetLoc("Flow.Dashboard.Name", "BRANCH NAME").PadRight(20)
         $sourceLabel = $this.GetLoc("Flow.Dashboard.Source", "SOURCE (Local)").PadRight(20)
         
         if ($index -eq 0) { $this.RenderItemLine(0, $targetLabel, $model.TargetBranch, $model.TargetBranchValid, $true) }
         elseif ($index -eq 1) { $this.RenderItemLine(1, $nameLabel, $model.NewBranchName, $model.NewBranchNameValid, $true) }
         elseif ($index -eq 2) { $this.RenderItemLine(2, $sourceLabel, $model.SourceBranch, $model.SourceBranchValid, $true) }

         $this.RenderActions($index, $model.IsReadyToExecute())
    }
}
