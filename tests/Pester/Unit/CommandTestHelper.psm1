# CommandTestHelper.psm1
$srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"

# Load Core Interfaces and Base
# We need NavigationState, RepositoryManager (Mock), Renderer (Mock)

function New-MockCommandContext {
    # Create simple mock objects using PSCustomObject
    
    $mockConsole = [PSCustomObject]@{
        Clear = { }
        WriteColored = { param($t, $c) }
        WriteLog = { param($m) }
    }
    
    $mockState = [PSCustomObject]@{
        SelectedPath = "C:\Repo"
        IsHiddenVisible = $false
        FilterText = ""
        SetDirty = { param($f) }
    }

    $mockHiddenService = [PSCustomObject]@{
        ToggleShowHidden = { }
    }

    $context = [PSCustomObject]@{
        Console = $mockConsole
        State = $mockState
        RepoManager = $mockRepoManager # Property used in command
        RepositoryManager = $mockRepoManager # Alias just in case
        HiddenReposService = $mockHiddenService
        InputHandler = $null
        CommandFactory = $null
        Services = @{}
    }
    
    return $context
}
