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
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "main" 
            } -ParameterFilter { $Arguments -contains "--abbrev-ref" }
            $script:service.GetCurrentBranch("C:\Repo") | Should -Be "main"
        }

        It "HasUncommittedChanges returns true if porcelain output is not empty" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "M file.txt" 
            } -ParameterFilter { $Arguments -contains "--porcelain" }
            $script:service.HasUncommittedChanges("C:\Repo") | Should -BeTrue
        }

        It "HasUnpushedCommits returns true if log returns output" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "main" 
            } -ParameterFilter { $Arguments -contains "--abbrev-ref" }
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "commit_hash" 
            } -ParameterFilter { $Arguments[0] -eq "log" }
            
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
    }

    Context "Branch Retrieval" {
        It "GetBranches returns array of local branches" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return @("main", "feature/test") 
            } -ParameterFilter { $Arguments -contains "branch" -and $Arguments -notcontains "-r" }
            $branches = $script:service.GetBranches("C:\Repo")
            $branches | Should -Contain "main"
            $branches | Should -Contain "feature/test"
        }

        It "GetRemoteBranches filters HEAD" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return @("origin/main", "origin/HEAD -> origin/main") 
            } -ParameterFilter { $Arguments -contains "-r" }
            $branches = $script:service.GetRemoteBranches("C:\Repo")
            $branches | Should -Contain "origin/main"
            $branches | Should -Not -Contain "origin/HEAD -> origin/main"
        }
    }

    Context "Tracking Status" {
        It "GetBranchTrackingStatus parses rev-list output" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "hash" 
            } -ParameterFilter { $Arguments -contains "--verify" }
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "1 2" 
            } -ParameterFilter { $Arguments -contains "rev-list" }
            
            $status = $script:service.GetBranchTrackingStatus("C:\Repo", "main")
            $status.Ahead | Should -Be 1
            $status.Behind | Should -Be 2
        }
        
        It "GetBranchTrackingStatus returns zeros when no upstream" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return "" } -ParameterFilter { $Arguments -contains "--verify" }
            
            $status = $script:service.GetBranchTrackingStatus("C:\Repo", "main")
            $status.Ahead | Should -Be 0
            $status.Behind | Should -Be 0
        }
        
        It "GetBranchTrackingStatus returns zeros on error" {
            Mock GitMockStub { throw "Error" }
            
            $status = $script:service.GetBranchTrackingStatus("C:\Repo", "main")
            $status.Ahead | Should -Be 0
            $status.Behind | Should -Be 0
        }
    }
    
    Context "Remote Branch Checking" {
        It "RemoteBranchExists returns true when branch exists" {
            Mock GitMockStub { $script:LASTEXITCODE = 0; return "hash" } -ParameterFilter { $Arguments -contains "--verify" }
            $script:service.RemoteBranchExists("C:\Repo", "main") | Should -BeTrue
        }
        
        It "RemoteBranchExists returns false when branch does not exist" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return "" } -ParameterFilter { $Arguments -contains "--verify" }
            $script:service.RemoteBranchExists("C:\Repo", "nonexistent") | Should -BeFalse
        }
    }
    
    Context "IsGitRepository" {
        It "Returns true when .git exists" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\.git" }
            $script:service.IsGitRepository("C:\Repo") | Should -BeTrue
        }
        
        It "Returns false when .git does not exist" {
            Mock Test-Path { return $false }
            $script:service.IsGitRepository("C:\NotRepo") | Should -BeFalse
        }
    }
    
    Context "GetGitStatus" {
        It "Returns complete status for valid repo" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "main" 
            } -ParameterFilter { $Arguments -contains "--abbrev-ref" }
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "M file.txt" 
            } -ParameterFilter { $Arguments -contains "--porcelain" }
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "commit" 
            } -ParameterFilter { $Arguments[0] -eq "log" }
            
            $status = $script:service.GetGitStatus("C:\Repo")
            $status.IsGitRepo | Should -BeTrue
            $status.CurrentBranch | Should -Be "main"
        }
        
        It "Returns empty status for non-repo" {
            Mock Test-Path { return $false }
            $status = $script:service.GetGitStatus("C:\NotRepo")
            $status.IsGitRepo | Should -BeFalse
        }
    }
    
    Context "GetCurrentBranch" {
        It "Returns empty string for non-repo" {
            Mock Test-Path { return $false }
            $script:service.GetCurrentBranch("C:\NotRepo") | Should -Be ""
        }
        
        It "Returns empty string when git fails" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return "" }
            $script:service.GetCurrentBranch("C:\Repo") | Should -Be ""
        }
    }
    
    Context "HasUncommittedChanges" {
        It "Returns false for non-repo" {
            Mock Test-Path { return $false }
            $script:service.HasUncommittedChanges("C:\NotRepo") | Should -BeFalse
        }
        
        It "Returns false when porcelain is empty" {
            Mock GitMockStub { return "" } -ParameterFilter { $Arguments -contains "--porcelain" }
            $script:service.HasUncommittedChanges("C:\Repo") | Should -BeFalse
        }
        
        It "Returns false when git fails" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return "" }
            $script:service.HasUncommittedChanges("C:\Repo") | Should -BeFalse
        }
    }
    
    Context "HasUnpushedCommits" {
        It "Returns false for non-repo" {
            Mock Test-Path { return $false }
            $script:service.HasUnpushedCommits("C:\NotRepo") | Should -BeFalse
        }
        
        It "Returns false when branch is empty" {
            Mock GitMockStub { return "" }
            $script:service.HasUnpushedCommits("C:\Repo") | Should -BeFalse
        }
        
        It "Returns false when log is empty" {
            Mock GitMockStub { return "main" } -ParameterFilter { $Arguments -contains "--abbrev-ref" }
            Mock GitMockStub { return "" } -ParameterFilter { $Arguments[0] -eq "log" }
            $script:service.HasUnpushedCommits("C:\Repo") | Should -BeFalse
        }
        
        It "Returns false on exception" {
            Mock GitMockStub { throw "Error" }
            $script:service.HasUnpushedCommits("C:\Repo") | Should -BeFalse
        }
    }
    
    Context "GetRemoteUrl" {
        It "Returns URL from git config" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "https://github.com/user/repo.git" 
            } -ParameterFilter { $Arguments -contains "remote.origin.url" }
            $script:service.GetRemoteUrl("C:\Repo") | Should -Be "https://github.com/user/repo.git"
        }
        
        It "Returns empty string for non-repo" {
            Mock Test-Path { return $false }
            $script:service.GetRemoteUrl("C:\NotRepo") | Should -Be ""
        }
        
        It "Returns empty string when git fails" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return "" }
            $script:service.GetRemoteUrl("C:\Repo") | Should -Be ""
        }
    }
    
    Context "GetRepoUrl" {
        It "Returns empty string when remote is empty" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "" 
            }
            $script:service.GetRepoUrl("C:\Repo") | Should -Be ""
        }
        
        It "Returns remote as-is when no pattern matches" {
            Mock GitMockStub { 
                $script:LASTEXITCODE = 0
                return "https://other.com/user/repo" 
            } -ParameterFilter { $Arguments -contains "remote.origin.url" }
            $script:service.GetRepoUrl("C:\Repo") | Should -Be "https://other.com/user/repo"
        }
    }
    
    Context "CountContainedRepositories" {
        It "Counts subdirectories that are git repos" {
            Mock Get-ChildItem { 
                return @(
                    [PSCustomObject]@{ FullName = "C:\Parent\Repo1" },
                    [PSCustomObject]@{ FullName = "C:\Parent\Repo2" },
                    [PSCustomObject]@{ FullName = "C:\Parent\NotRepo" }
                )
            }
            Mock Test-Path { 
                param($Path) 
                return ($Path -like "*Repo1\.git") -or ($Path -like "*Repo2\.git")
            }
            
            $count = $script:service.CountContainedRepositories("C:\Parent")
            $count | Should -Be 2
        }
        
        It "Returns zero when no subdirectories" {
            Mock Get-ChildItem { return @() }
            $script:service.CountContainedRepositories("C:\Empty") | Should -Be 0
        }
    }
    
    Context "IsContainerDirectory" {
        It "Returns false when path is a git repository" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*\.git" }
            $script:service.IsContainerDirectory("C:\Repo") | Should -BeFalse
        }
        
        It "Returns true when path is not a git repository" {
            Mock Test-Path { return $false }
            $script:service.IsContainerDirectory("C:\Container") | Should -BeTrue
        }
    }
    
    Context "GetBranches Edge Cases" {
        It "Returns empty array for non-repo" {
            Mock Test-Path { return $false }
            $script:service.GetBranches("C:\NotRepo") | Should -BeNullOrEmpty
        }
        
        It "Returns empty array when git fails" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return $null }
            $script:service.GetBranches("C:\Repo") | Should -BeNullOrEmpty
        }
    }
    
    Context "GetRemoteBranches Edge Cases" {
        It "Returns empty array for non-repo" {
            Mock Test-Path { return $false }
            $script:service.GetRemoteBranches("C:\NotRepo") | Should -BeNullOrEmpty
        }
        
        It "Returns empty array when git fails" {
            Mock GitMockStub { $script:LASTEXITCODE = 1; return $null }
            $script:service.GetRemoteBranches("C:\Repo") | Should -BeNullOrEmpty
        }
    }
    
    Context "GetBranchTrackingStatus Edge Cases" {
        It "Returns zeros for non-repo" {
            Mock Test-Path { return $false }
            $status = $script:service.GetBranchTrackingStatus("C:\NotRepo", "main")
            $status.Ahead | Should -Be 0
            $status.Behind | Should -Be 0
        }
    }
    
    Context "RemoteBranchExists Edge Cases" {
        It "Returns false for non-repo" {
            Mock Test-Path { return $false }
            $script:service.RemoteBranchExists("C:\NotRepo", "main") | Should -BeFalse
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
