<#
.SYNOPSIS
    MenuRenderer - Handles rendering of the menu and instructions
    
.DESCRIPTION
    Extracted from UIRenderer to follow SRP.
    Responsible for rendering the bottom menu/instructions area.
#>

class MenuRenderer {
    [ConsoleHelper] $Console
    [UserPreferencesService] $PreferencesService
    [LocalizationService] $LocalizationService

    # Constructor
    MenuRenderer([ConsoleHelper]$console, [UserPreferencesService]$preferencesService, [LocalizationService]$localizationService) {
        $this.Console = $console
        $this.PreferencesService = $preferencesService
        $this.LocalizationService = $localizationService
    }

    # Helper for localization
    hidden [string] GetLoc([string]$key, [string]$default) {
        if ($null -ne $this.LocalizationService) {
            return $this.LocalizationService.Get($key)
        }
        return $default
    }

    # Render menu/instructions
    [int] RenderMenu([string]$mode) {
        $this.Console.NewLine()
        $linesRendered = 1 # Initial empty line
        
        if ($mode -eq 'Hidden') {
             return $linesRendered
        }
        
        # Minimal Mode: Only Nav and Exit (compact)
        if ($mode -eq 'Minimal') {
             $grpNav = $this.GetLoc("UI.Group.Nav", "Navigation")
             $cmdNav = $this.GetLoc("Cmd.Desc.Nav", "Arrows | Enter=open")
             $cmdExit = $this.GetLoc("Cmd.Desc.Exit", "Q=quit")
             $cmdPref = $this.GetLoc("Cmd.Desc.Pref", "U=preferences")
             
             $this.Console.WriteLineColored("  $cmdNav | $cmdExit | $cmdPref", [Constants]::ColorMenuText)
             $linesRendered++
             $this.Console.NewLine()
             $linesRendered++
             return $linesRendered
        }
        
        # Determine visibility based on mode
        $showNav     = $true
        $showAlias   = $true
        $showModules = $true
        $showRepo    = $true
        $showGit     = $true
        $showTools   = $true
        
        if ($mode -eq 'Custom') {
            $preferences = $this.PreferencesService.LoadPreferences()
            if ($preferences.display.PSObject.Properties.Name -contains 'menuSections') {
                $sections = $preferences.display.menuSections
                $showNav     = if ($sections.PSObject.Properties.Name -contains 'navigation') { $sections.navigation } else { $true }
                $showAlias   = if ($sections.PSObject.Properties.Name -contains 'alias') { $sections.alias } else { $true }
                $showModules = if ($sections.PSObject.Properties.Name -contains 'modules') { $sections.modules } else { $true }
                $showRepo    = if ($sections.PSObject.Properties.Name -contains 'repository') { $sections.repository } else { $true }
                $showGit     = if ($sections.PSObject.Properties.Name -contains 'git') { $sections.git } else { $true }
                $showTools   = if ($sections.PSObject.Properties.Name -contains 'tools') { $sections.tools } else { $true }
            }
        }
        
        # Common constants
        $labelWidth = 13 
        
        if ($showNav) {
            $linesRendered += $this.RenderSectionNavigation($labelWidth)
        }
        
        if ($showAlias) {
            $linesRendered += $this.RenderSectionAlias($labelWidth)
        }
        
        if ($showModules) {
            $linesRendered += $this.RenderSectionModules($labelWidth)
        }
        
        if ($showRepo) {
            $linesRendered += $this.RenderSectionRepository($labelWidth)
        }
        
        if ($showGit) {
            $linesRendered += $this.RenderSectionGitStatus($labelWidth)
        }
        
        if ($showTools) {
             $linesRendered += $this.RenderSectionTools($labelWidth)
        }
        
        $this.Console.NewLine()
        $linesRendered++
        
        return $linesRendered
    }
    
    # Helper: Render Navigation Section
    hidden [int] RenderSectionNavigation([int]$labelWidth) {
        $grpNav = $this.GetLoc("UI.Group.Nav", "Navigation")
        $cmdNav = $this.GetLoc("Cmd.Desc.Nav", "Arrows | Enter=open")
        $cmdExit = $this.GetLoc("Cmd.Desc.Exit", "Q=quit")
        # Prefs moved to Tools
        
        $lblNav = "${grpNav}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblNav $cmdNav | $cmdExit", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Alias Section
    hidden [int] RenderSectionAlias([int]$labelWidth) {
        $cmdAlias = $this.GetLoc("Cmd.Desc.Alias", "E=set | R=remove")
        $lblAlias = "Alias:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblAlias $cmdAlias", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Modules Section
    hidden [int] RenderSectionModules([int]$labelWidth) {
        $grpMod = $this.GetLoc("UI.Group.Modules", "Modules")
        $cmdNpm = $this.GetLoc("Cmd.Desc.Npm", "I=install | X=remove")
        $lblMod = "${grpMod}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblMod $cmdNpm", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Repository Section
    hidden [int] RenderSectionRepository([int]$labelWidth) {
        $grpRepo = $this.GetLoc("UI.Group.Repo", "Repository")
        $cmdClone = $this.GetLoc("Cmd.Desc.RepoMgmt", "C=clone | Del=delete")
        $cmdFav = $this.GetLoc("Cmd.Desc.Favorite", "Space=favorite")
        $lblRepo = "${grpRepo}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblRepo $cmdClone | $cmdFav", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Git Status Section
    hidden [int] RenderSectionGitStatus([int]$labelWidth) {
        $cmdGit = $this.GetLoc("Cmd.Desc.Git", "L=load current | G=load all")
        $lblGit = "Git Status:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblGit $cmdGit", [Constants]::ColorMenuText)
        return 1
    }
    
    # Helper: Render Tools Section
    hidden [int] RenderSectionTools([int]$labelWidth) {
        $grpTool = $this.GetLoc("UI.Group.Tools", "Tools")
        $cmdPref = $this.GetLoc("Cmd.Desc.Pref", "U=preferences")
        $cmdFolder = $this.GetLoc("Cmd.Desc.CreateFolder", "N=New Folder")
        $cmdSearch = $this.GetLoc("Cmd.Desc.Search", "S=Search")
        
        $lblTool = "${grpTool}:".PadRight($labelWidth)
        $this.Console.WriteLineColored("  $lblTool $cmdSearch | $cmdFolder | $cmdPref", [Constants]::ColorMenuText)
        return 1
    }
}
