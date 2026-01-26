<#
.SYNOPSIS
    CreateFolderCommand - Handles creating a new folder in the current directory
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only handles creation of folders
    - DIP: Depends on services via context
#>

class CreateFolderCommand : INavigationCommand {
    [string] GetDescription() {
        return "Create Folder (N)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_N
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $console = $context.Console
        $state = $context.State
        $repoManager = $context.RepoManager
        $getLoc = $context.LocalizationService
        
        $currentPath = $state.GetCurrentPath()
        if (-not $currentPath) {
            $currentPath = $context.BasePath
        }
        
        # 1. Prompt for name
        $console.ShowCursor()
        $prompt = "Enter folder name (no spaces): "
        $console.WriteColored($prompt, [Constants]::ColorPrompt)
        
        $folderName = Read-Host
        $console.HideCursor()
        
        if ([string]::IsNullOrWhiteSpace($folderName)) {
            $context.Renderer.RenderWarning("Folder creation cancelled (empty name).")
            Start-Sleep -Seconds 1
            $state.MarkForFullRedraw()
            return
        }
        
        # 2. Call service
        $result = $repoManager.RepoOperationsService.CreateFolder($folderName.Trim(), $currentPath)
        
        if ($result.Success) {
            $context.Renderer.RenderSuccess($result.Message)
            
            # 3. Reload current view
            # If inside a container
            if ($state.CanGoBack()) {
                # We are in a container, reload container
                 $repoManager.LoadContainerRepositories($currentPath, $state.NavigationStack.Peek().Path)
            } else {
                # We are at root
                 $repoManager.LoadRepositories($currentPath)
            }
            
            $newRepos = $repoManager.GetRepositories()
            $state.Repositories = $newRepos
             
            # Try to select the new folder
            $newIndex = $state.FindRepositoryIndex($folderName)
            $state.SetCurrentIndex($newIndex)
            
            $state.MarkForFullRedraw()
            Start-Sleep -Seconds 1
        }
        else {
            $context.Renderer.RenderError($result.Message)
            Start-Sleep -Seconds 2
            $state.MarkForFullRedraw()
        }
    }
}
