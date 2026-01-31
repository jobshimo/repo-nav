# tests/Pester/Unit/Services/GitReadService.Tests.ps1

Describe "GitReadService" {
    BeforeAll {
        # Force a git ALIAS to exist so it has higher precedence than git.exe
        # We point it to a function that Pester will then mock
        if (-not (Get-Command git -CommandType Alias -ErrorAction SilentlyContinue)) {
            function global:GitMockStub { param([Parameter(ValueFromRemainingArguments=$true)]$Arguments) }
            Set-Alias -Name git -Value GitMockStub -Scope Global -Option AllScope
        }

        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\..\src"
        $projectRoot = Resolve-Path "$PSScriptRoot\..\..\..\.."
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        . "$srcRoot\Models\GitStatusModel.ps1"
        . "$srcRoot\Services\GitReadService.ps1"
    }

    BeforeEach {
        $script:service = [GitReadService]::new()
        
        # Mock Test-Path to simulate a .git folder exists
        Mock Test-Path { return $true }
        
        # Mock Push-Location/Pop-Location
        Mock Push-Location { }
        Mock Pop-Location { }
        
        # Mock the function our alias points to
        Mock GitMockStub { }
    }

    Context "Git Mocking Quality" {
        It "GetCurrentBranch returns branch name from git rev-parse" {
            Mock GitMockStub { return "main" } -ParameterFilter { $Arguments -contains "--abbrev-ref" }
            $script:service.GetCurrentBranch("C:\Repo") | Should -Be "main"
        }

        It "HasUncommittedChanges returns true if porcelain output is not empty" {
            Mock GitMockStub { return "M file.txt" } -ParameterFilter { $Arguments -contains "--porcelain" }
            $script:service.HasUncommittedChanges("C:\Repo") | Should -BeTrue
        }

        It "HasUnpushedCommits returns true if log returns output" {
            Mock GitMockStub { return "main" } -ParameterFilter { $Arguments -contains "--abbrev-ref" }
            Mock GitMockStub { return "commit_hash" } -ParameterFilter { $Arguments[0] -eq "log" }
            
            $script:service.HasUnpushedCommits("C:\Repo") | Should -BeTrue
        }
    }

    Context "URL Parsing Logic" {
        It "Validates Git URLs" {
            $script:service.IsValidGitUrl("https://github.com/user/repo.git") | Should -BeTrue
            $script:service.IsValidGitUrl("https://github.com/user/repo") | Should -BeTrue
            $script:service.IsValidGitUrl("https://other.com/repo") | Should -BeFalse
        }

        It "Extracts repo name from URL" {
            $script:service.GetRepoNameFromUrl("https://github.com/user/my-repo.git") | Should -Be "my-repo"
            $script:service.GetRepoNameFromUrl("https://github.com/user/another-repo") | Should -Be "another-repo"
        }

        It "Converts SSH/HTTPS to clean HTTPS URL" {
            Mock GitMockStub { return "git@github.com:user/repo.git" } -ParameterFilter { $Arguments -contains "remote.origin.url" }
            $script:service.GetRepoUrl("C:\Repo") | Should -Be "https://github.com/user/repo"

            Mock GitMockStub { return "https://github.com/user/repo.git" } -ParameterFilter { $Arguments -contains "remote.origin.url" }
            $script:service.GetRepoUrl("C:\Repo") | Should -Be "https://github.com/user/repo"
        }
    }

    Context "Branch Retrieval" {
        It "GetBranches returns array of local branches" {
            Mock GitMockStub { return "main", "feature/test" } -ParameterFilter { $Arguments -contains "branch" -and $Arguments -notcontains "-r" }
            $branches = $script:service.GetBranches("C:\Repo")
            $branches | Should -Contain "main"
            $branches | Should -Contain "feature/test"
        }

        It "GetRemoteBranches filters HEAD" {
            Mock GitMockStub { return "origin/main", "origin/HEAD -> origin/main" } -ParameterFilter { $Arguments -contains "-r" }
            $branches = $script:service.GetRemoteBranches("C:\Repo")
            $branches | Should -Contain "origin/main"
            $branches | Should -Not -Contain "origin/HEAD -> origin/main"
        }
    }

    Context "Tracking Status" {
        It "GetBranchTrackingStatus parses rev-list output" {
            Mock GitMockStub { return "hash" } -ParameterFilter { $Arguments -contains "--verify" }
            Mock GitMockStub { return "1 2" } -ParameterFilter { $Arguments -contains "rev-list" }
            
            $status = $script:service.GetBranchTrackingStatus("C:\Repo", "main")
            $status.Ahead | Should -Be 1
            $status.Behind | Should -Be 2
        }
    }

    AfterAll {
        if (Get-Alias git -ErrorAction SilentlyContinue) {
             Remove-Item Alias:git -ErrorAction SilentlyContinue
        }
        if (Get-Command GitMockStub -ErrorAction SilentlyContinue) {
             # Remove-Item function:global:GitMockStub -ErrorAction SilentlyContinue
        }
    }
}
