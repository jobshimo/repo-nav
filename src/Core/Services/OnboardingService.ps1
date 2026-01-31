<#
.SYNOPSIS
    OnboardingService - Manages initial user setup and empty states.
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Handles only the onboarding/setup flow.
    - DIP: Depends on abstractions via injection.
#>

class OnboardingService {
    [IUIRenderer] $Renderer
    [ConsoleHelper] $Console
    [LocalizationService] $Loc
    [OptionSelector] $OptionSelector
    [UserPreferencesService] $PreferencesService

    OnboardingService(
        [IUIRenderer]$renderer,
        [ConsoleHelper]$console,
        [LocalizationService]$loc,
        [OptionSelector]$optionSelector,
        [UserPreferencesService]$preferencesService
    ) {
        $this.Renderer = $renderer
        $this.Console = $console
        $this.Loc = $loc
        $this.OptionSelector = $optionSelector
        $this.PreferencesService = $preferencesService
    }

    # Handles the scenario where no repositories are found.
    # Returns the new path if configured, or $null if cancelled/failed.
    [string] HandleEmptyState([string]$currentPath) {
        $title = $this.Loc.Get("Onboarding.Title")
        
        $msgKey = if ([string]::IsNullOrWhiteSpace($currentPath)) { "Onboarding.InitialSetup" } else { "Onboarding.NoRepos" }
        $msgArg = if ($msgKey -eq "Onboarding.NoRepos") { $currentPath } else { $null }
        $msg = $this.Loc.Get($msgKey, $msgArg)
        
        $promptMsg = $this.Loc.Get("Onboarding.PromptConfig")
        
        # Configure SelectionOptions for clean rendering
        $config = [SelectionOptions]::new()
        $config.Title = $title
        $config.Description = "$msg`n`n  $promptMsg"
        $config.DescriptionColor = "Yellow"
        $config.ClearScreen = $true
        $config.CancelText = $this.Loc.Get("Prompt.Cancel")
        $config.ShowCurrentMarker = $false
        
        $yesText = $this.Loc.Get("Prompt.Yes")
        $noText = $this.Loc.Get("Prompt.No")
        
        $config.Options = @(
            @{ DisplayText = $yesText; Value = $true },
            @{ DisplayText = $noText; Value = $false }
        )
        
        $result = $this.OptionSelector.Show($config)
        
        if ($result -eq $true) {
            $this.Console.ShowCursor()
            Write-Host ""
            
            $enterPathMsg = $this.Loc.Get("Onboarding.EnterPath")
            Write-Host "  $enterPathMsg" -ForegroundColor Yellow
            
            $newPath = Read-Host "  > "
            $this.Console.HideCursor()
            
            $newPath = $newPath.TrimStart('"').TrimEnd('"')
            
            if (-not [string]::IsNullOrWhiteSpace($newPath) -and (Test-Path $newPath)) {
                $resolvedPath = (Resolve-Path $newPath).Path
                
                # Save to Preferences
                $this.PreferencesService.EnsurePathInPreferences($resolvedPath)
                $this.PreferencesService.SetPreference("repository", "defaultPath", $resolvedPath)
                
                $successMsg = $this.Loc.Get("Onboarding.Success")
                $this.Renderer.RenderSuccess($successMsg)
                Start-Sleep -Seconds 1
                
                return $resolvedPath
            } else {
                $invalidMsg = $this.Loc.Get("Onboarding.InvalidPath")
                $this.Renderer.RenderError($invalidMsg)
                Start-Sleep -Seconds 2
                return $null
            }
        }
        
        return $null
    }
}
