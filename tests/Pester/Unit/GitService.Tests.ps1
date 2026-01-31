Describe "GitService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        
        # Load Models (Conditional)
        if (-not ("GitStatusModel" -as [type])) { . "$srcRoot\Models\GitStatusModel.ps1" }
        if (-not ("RepositoryModel" -as [type])) { . "$srcRoot\Models\RepositoryModel.ps1" }
        if (-not ("AliasInfo" -as [type])) { . "$srcRoot\Models\AliasInfo.ps1" }
        if (-not ("OperationResult" -as [type])) { . "$srcRoot\Core\Common\OperationResult.ps1" }
        
        # Load GitService
        if (-not ("GitService" -as [type])) { . "$srcRoot\Services\GitService.ps1" }
    }

    Context "Git Parsing Logic" {
        It "Simulates Git calls correctly" {
            $service = [GitService]::new()
            
            # Global Mock for Git
            Mock git {
                $global:LASTEXITCODE = 0 # Simulate success
                $argsStr = $Args -join " "
                
                # rev-parse HEAD -> current branch
                # Using simple matching to be robust
                if ($argsStr -match "rev-parse" -and $argsStr -match "HEAD") { return "main" }
                
                # status --porcelain -> uncommitted changes
                if ($argsStr -match "status" -and $argsStr -match "porcelain") { return "M Modified.txt" }
                
                # rev-parse @{u} (upstream)
                if ($argsStr -match "rev-parse" -and $argsStr -match "@{u}") { return "origin/main" }
                
                # log origin/branch..HEAD -> unpushed
                if ($argsStr -match "log" -and $argsStr -match "\.\.HEAD") { return "commit-hash" }
                
                return "" 
            }
            
            Mock Test-Path { return $true }
            Mock Push-Location {}
            Mock Pop-Location {}
            
            $service.GetCurrentBranch("C:\Repo") | Should -Be "main"
            $service.HasUncommittedChanges("C:\Repo") | Should -BeTrue
            $service.HasUnpushedCommits("C:\Repo") | Should -BeTrue
        }

        It "CloneRepository calls git clone" {
            $service = [GitService]::new()
            Mock git { return "Cloning..." }
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            # Pass 3 arguments as PS classes don't support optional params well locally
            $result = $service.CloneRepository("https://github.com/User/Repo.git", "C:\Target", "")
            $result.Success | Should -BeTrue
        }
        
        It "Fetch calls git fetch" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.Fetch("C:\Repo")
            $result.Success | Should -BeTrue
        }
        
        It "Pull calls git pull" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.Pull("C:\Repo")
            $result.Success | Should -BeTrue
        }
        
        It "Push calls git push" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.Push("C:\Repo", "main")
            $result.Success | Should -BeTrue
        }
        
        It "Commit calls git commit" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.Commit("C:\Repo", "msg")
            $result.Success | Should -BeTrue
        }
        
        It "Add calls git add" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.Add("C:\Repo", ".")
            $result.Success | Should -BeTrue
        }
        
        It "Stash calls git stash" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.Stash("C:\Repo", "msg")
            $result.Success | Should -BeTrue
        }
        
        It "DeleteLocalBranch calls git branch -d" {
            $service = [GitService]::new()
            Mock git {} 
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.DeleteLocalBranch("C:\Repo", "feature", $false)
            $result.Success | Should -BeTrue
        }
        
        It "DeleteRemoteBranch calls git push --delete" {
            $service = [GitService]::new()
            Mock git {}
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $result = $service.DeleteRemoteBranch("C:\Repo", "feature")
            $result.Success | Should -BeTrue
        }
        
        It "GetBranches returns list" {
            $service = [GitService]::new()
            Mock git { return "main","develop" } -ParameterFilter { $Args -contains "branch" }
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Test-Path { return $true }
            
            $branches = $service.GetBranches("C:\Repo")
            $branches.Count | Should -Be 2
        }
    }

    It "IsValidGitUrl validates HTTPS Github URLs" {
        $service = [GitService]::new()
        $service.IsValidGitUrl("https://github.com/User/Repo.git") | Should -BeTrue
        $service.IsValidGitUrl("ftp://bad.url") | Should -BeFalse
    }
}
