class IntegrationFlowRenderer {
    [object] $Console
    [object] $Renderer

    IntegrationFlowRenderer([object]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
    }

    [void] RenderInteractiveDashboard([hashtable]$flowState, [int]$selectedIndex) {
        $this.Renderer.RenderHeader("INTEGRATION FLOW DASHBOARD")
        $this.Console.NewLine()
        
        # Items mapping:
        # 0: Target Branch
        # 1: New Branch Name
        # 2: Source Branch
        # 3: Execute (if valid) OR Exit (if invalid) -- actually list should be dynamic
        
        # 0. Target Item
        $this.RenderStateItem(0, "TARGET (Remote)      ", $flowState.TargetBranch, $flowState.TargetBranchValid, ($selectedIndex -eq 0))
        
        # 1. New Branch Item
        $this.RenderStateItem(1, "BRANCH NAME          ", $flowState.NewBranchName, $flowState.NewBranchNameValid, ($selectedIndex -eq 1))
        
        # 2. Source Item
        $this.RenderStateItem(2, "SOURCE (Local)       ", $flowState.SourceBranch, $flowState.SourceBranchValid, ($selectedIndex -eq 2))
        
        $this.Console.NewLine()
        
        # Calculate dynamic index for Execute/Exit
        $canExecute = $flowState.TargetBranchValid -and $flowState.NewBranchNameValid -and $flowState.SourceBranchValid
        
        if ($canExecute) {
            # 3. Execute
            $isSel = ($selectedIndex -eq 3)
            $prefix = if ($isSel) { "  > " } else { "    " }
            # If valid, show reliable Execute option
            $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
            $color = if ($isSel) { [Constants]::ColorSelected } else { [Constants]::ColorSuccess }
            $this.Console.WriteLineColored("[ EXECUTE INTEGRATION ]", $color)
            
            # 4. Exit
            $isSelExit = ($selectedIndex -eq 4)
            $prefixExit = if ($isSelExit) { "  > " } else { "    " }
            $this.Console.WriteColored($prefixExit, [Constants]::ColorHighlight)
            $colorExit = if ($isSelExit) { [Constants]::ColorSelected } else { [Constants]::ColorHint }
            $this.Console.WriteLineColored("[ Exit / Cancel ]", $colorExit)
        } else {
            # 3. Exit (since Execute is hidden/disabled)
            $isSel = ($selectedIndex -eq 3)
            $prefix = if ($isSel) { "  > " } else { "    " }
            $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
            $color = if ($isSel) { [Constants]::ColorSelected } else { [Constants]::ColorHint }
            $this.Console.WriteLineColored("[ Exit / Cancel ]", $color)
        }
        
        $this.Console.NewLine()
        $this.Console.WriteLineColored("  Use Arrows to navigate | Enter to edit/select", [Constants]::ColorHint)
    }

    hidden [void] RenderStateItem([int]$index, [string]$label, [string]$value, [bool]$isValid, [bool]$isSelected) {
        $prefix = if ($isSelected) { "  > " } else { "    " }
        
        $this.Console.WriteColored($prefix, [Constants]::ColorHighlight)
        $this.Console.WriteColored("$label : ", [Constants]::ColorLabel)
        
        if ([string]::IsNullOrWhiteSpace($value)) {
            $this.Console.WriteLineColored("<Not Selected>", [Constants]::ColorHint)
        } else {
            $color = if ($isValid) { [Constants]::ColorValue } else { [Constants]::ColorWarning }
            $this.Console.WriteLineColored($value, $color)
        }
    }

    [void] RenderExecutionStatus([string]$message, [bool]$success) {
        $color = if ($success) { [Constants]::ColorSuccess } else { [Constants]::ColorError }
        $prefix = if ($success) { "[v]" } else { "[x]" }
        $this.Console.WriteLineColored("  $prefix $message", $color)
    }
}
