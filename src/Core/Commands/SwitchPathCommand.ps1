class SwitchPathCommand : INavigationCommand {
    [string] GetDescription() {
        return "Switch Repository Path (P)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_P
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        # Check if already in a sub-view (like prefs)
        # We generally assume Commands are run from Main View or specific contexts
        
        $preferences = $context.PreferencesService.LoadPreferences()
        $paths = if ($preferences.repository.paths) { $preferences.repository.paths } else { @() }
        $currentPath = $context.BasePath
        
        # Initialize variables
        $inputPath = $null

        # Build options
        $options = @()
        
        # Add Current if not in list (handling missing/uninit cases)
        if (-not [string]::IsNullOrEmpty($currentPath)) {
            $inList = $false
            foreach ($p in $paths) { if ($p -eq $currentPath) { $inList = $true; break } }
            
            # If current path is not in the saved list, maybe we should offer to save it?
            # For now, just show it as an option so user knows where they are
        }
        
        $pathAliases = if ($preferences.repository.pathAliases) { $preferences.repository.pathAliases } else { ([PSCustomObject]@{}) }
        $defaultPath = if ($preferences.repository.defaultPath) { $preferences.repository.defaultPath } else { "" }
        
        foreach ($p in $paths) {
             # Resolve Alias
             $displayAlias = ""
             if ($pathAliases.$p) { 
                 $aliasVal = $pathAliases.$p
                 if ($aliasVal -is [string]) {
                     $displayAlias = " [$aliasVal]"
                 } elseif ($aliasVal.PSObject.Properties.Name -contains 'Text') {
                     $displayAlias = " [$($aliasVal.Text)]"
                 }
             }
        
             $displayText = "$p$displayAlias"
             
             # OptionSelector automatically adds (current) when ShowCurrentMarker is true
             
             if ($p -eq $defaultPath) {
                 $displayText += " (Default)"
             }
             if (-not (Test-Path $p)) {
                 $displayText += " (Missing)"
             }
             $options += @{ Value = $p; DisplayText = $displayText }
        }
        
        # Always add option to type custom path
        $options += @{ Value = "TYPE_CUSTOM"; DisplayText = "[+] Type Custom Path..." }
        
        $config = [SelectionOptions]::new()
        $config.Title = "Switch Repository Path"
        $config.Options = $options
        $config.CurrentValue = $currentPath
        $config.ShowCurrentMarker = $true
        $config.CancelText = "Back"
        
        $selectedPath = $context.OptionSelector.Show($config)
        
        if ($selectedPath -eq "TYPE_CUSTOM") {
            $context.Console.ClearScreen()
            $context.Renderer.RenderHeader("SWITCH PATH")
            Write-Host ""
            Write-Host "  Enter absolute path:" -ForegroundColor Yellow
            $context.Console.ShowCursor()
            $inputPath = Read-Host "  > "
            $context.Console.HideCursor()
            
            if (-not [string]::IsNullOrWhiteSpace($inputPath)) {
                $selectedPath = $inputPath
            } else {
                return 
            }
        }
        
        if ($null -ne $selectedPath -and ($selectedPath -ne $currentPath -or $selectedPath -eq $inputPath)) {
            # Normalize
            if (Test-Path $selectedPath) {
                $selectedPath = (Resolve-Path $selectedPath).Path
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
                
                # 6. Ensure this new path is in preferences (if it was typed manually)
                $context.PreferencesService.EnsurePathInPreferences($selectedPath)
                
            } else {
                $context.Renderer.RenderError("Path not found: $selectedPath")
                Start-Sleep -Seconds 2
            }
        }
    }
}
