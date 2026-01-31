# Mock classes must be in a separate file to allow parsing after dependencies are loaded

class MockNpmService : INpmService {
    [bool] $PackageJsonExists
    [string] $NpmPath
    [bool] $NodeModulesExists
    
    MockNpmService() { 
        $this.PackageJsonExists = $true 
        $this.NpmPath = "C:\fake\npm.exe"
        $this.NodeModulesExists = $true
    }
    
    [bool] HasPackageJson([string]$path) { return $this.PackageJsonExists }
    [string] GetNpmExecutablePath() { return $this.NpmPath }
    [bool] HasNodeModules([string]$path) { return $this.NodeModulesExists }
    [bool] HasPackageLock([string]$path) { return $false }
    [string] GetVersion() { return "1.0.0" }
}

class MockJobSuccess {
    [string] $State = 'Completed'
    [System.Collections.ArrayList] $ChildJobs
    
    MockJobSuccess() {
        $this.ChildJobs = New-Object System.Collections.ArrayList
        $sub = [PSCustomObject]@{ Error = $null }
        $this.ChildJobs.Add($sub) | Out-Null
    }
}

class MockJobServiceV10 : IJobService {
    [scriptblock] $LastScript
    [array] $LastArgs
    
    [object] StartJob([scriptblock]$scriptBlock, [array]$args) {
        Write-Host "DEBUG SERVICE: StartJob Called"
        $this.LastScript = $scriptBlock
        $this.LastArgs = $args
        
        $list = New-Object System.Collections.ArrayList
        $sub = New-Object PSObject
        $sub | Add-Member -MemberType NoteProperty -Name 'Error' -Value $null
        $list.Add($sub) | Out-Null
        
        $j = New-Object PSObject
        $j | Add-Member -MemberType NoteProperty -Name 'State' -Value 'Completed'
        $j | Add-Member -MemberType NoteProperty -Name 'ChildJobs' -Value $list
        
        Write-Host "DEBUG SERVICE: Created object State=$($j.State)"
        return $j
    }
    
    [object] ReceiveJob([object]$job) { return $true }
    [void] RemoveJob([object]$job, [bool]$force) { }
}


class MockLocalizationService : ILocalizationService {
    [string] Get([string]$key) { return $key }
    [string] Get([string]$key, [string]$default) { return $default }
    [void] SetLanguage([string]$lang) {}
    [string] GetCurrentLanguage() { return "en" }
    [hashtable] GetAll() { return @{} }
    [void] Reload() {}
}

class MockOptionSelectorV2 : IOptionSelector {
    [bool] $AlwaysConfirm
    
    MockOptionSelectorV2() { $this.AlwaysConfirm = $true }
    
    [object] Show([SelectionOptions]$options) { 
        return $true 
    }
}

class MockUIRenderer : IUIRenderer {
    [void] RenderRepositoryList([NavigationState]$state, [int]$width, [int]$height) {}
    [void] RenderHeader([string]$filter, [int]$repoCount, [int]$loadedCount) {}
    [void] RenderHelp() {}
    [void] RenderError([string]$message) {}
    [void] RenderWorkflowHeader([string]$title, [object]$repository) {}
    [void] RenderLoading() {}
    [void] RenderStatus([string]$message) {}
    [string] TruncatePath([string]$path, [int]$length) { return $path }
    [void] RenderDetail([object]$repository) {}
}
