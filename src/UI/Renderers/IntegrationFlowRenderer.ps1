class IntegrationFlowRenderer {
    [object] $Console
    [object] $Renderer

    IntegrationFlowRenderer([object]$console, [object]$renderer) {
        $this.Console = $console
        $this.Renderer = $renderer
    }

    [void] RenderDashboard([hashtable]$flowState) {
        $this.Renderer.RenderHeader("INTEGRATION FLOW DASHBOARD")
        $this.Console.NewLine()
        
        # Display Current State with visual hierarchy
        $this.RenderStateItem("TARGET (Remote)", $flowState.TargetBranch, $flowState.TargetBranchValid)
        $this.RenderStateItem("BRANCH NAME",     $flowState.NewBranchName, $flowState.NewBranchNameValid)
        $this.RenderStateItem("SOURCE (Local)",  $flowState.SourceBranch, $flowState.SourceBranchValid)
        
        $this.Console.NewLine()
    }

    hidden [void] RenderStateItem([string]$label, [string]$value, [bool]$isValid) {
        # Label with fixed width for alignment
        $labelPad = $label.PadRight(20)
        
        $this.Console.WriteColored("  $labelPad : ", [Constants]::ColorLabel)
        
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
