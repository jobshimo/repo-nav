class SwitchPathCommand : INavigationCommand {
    [string] GetDescription() {
        return "Switch Repository Path (P)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_P
    }

    [void] Execute([CommandContext]$context) {
        # Check if already in a sub-view (like prefs)
        # We generally assume Commands are run from Main View or specific contexts
        
        $preferences = $context.PreferencesService.LoadPreferences()
        $paths = if ($preferences.repository.paths) { $preferences.repository.paths } else { @() }
        $currentPath = $context.BasePath

        # Build options
        $options = @()
        
        # Add Current if not in list (handling missing/uninit cases)
        if (-not [string]::IsNullOrEmpty($currentPath)) {
            $inList = $false
            foreach ($p in $paths) { if ($p -eq $currentPath) { $inList = $true; break } }
            
            # If current path is not in the saved list, maybe we should offer to save it?
            # For now, just show it as an option so user knows where they are
        }
        
        foreach ($p in $paths) {
             $displayText = $p
             if ($p -eq $currentPath) {
                 $displayText += " (Current)"
             }
             if (-not (Test-Path $p)) {
                 $displayText += " (Missing)"
             }
             $options += @{ Value = $p; DisplayText = $displayText }
        }
        
        if ($options.Count -eq 0) {
            $context.Renderer.RenderWarning("No additional repository paths configured. Go to Preferences > Manage Repository Paths.")
            Start-Sleep -Seconds 1
            return
        }
        
        $config = [SelectionOptions]::new()
        $config.Title = "Switch Repository Path"
        $config.Options = $options
        $config.CurrentValue = $currentPath
        $config.ShowCurrentMarker = $true
        $config.CancelText = "Back"
        
        $selectedPath = $context.OptionSelector.Show($config)
        
        if ($null -ne $selectedPath -and $selectedPath -ne $currentPath) {
            if (Test-Path $selectedPath) {
                $context.Renderer.RenderSuccess("Switching to: $selectedPath")
                
                # Update Context and State
                
                # 1. Update persisted base path in Context
                $context.BasePath = $selectedPath
                
                # 2. Update NavigationState
                $context.State.SetBasePath($selectedPath)
                $context.State.SetCurrentPath($selectedPath)
                $context.State.NavigationStack.Clear()
                
                # 3. Reload Repositories via Manager
                $context.RepoManager.LoadRepositories($selectedPath, $true)
                
                # 4. Update State with new repos
                $repos = $context.RepoManager.GetRepositories()
                $context.State.UpdateRepositories($repos)
                $context.State.SetCurrentIndex(0)
                
                # 5. Reset viewport
                $context.State.ViewportStart = 0
                $context.State.SelectionChanged = $false
                $context.State.MarkForFullRedraw()
                
            } else {
                $context.Renderer.RenderError("Path not found: $selectedPath")
                Start-Sleep -Seconds 2
            }
        }
    }
}
