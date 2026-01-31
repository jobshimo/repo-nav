Describe "GitService" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        
        # GitMockStub Pattern (Mandatory)
        function global:GitMockStub { param([Parameter(ValueFromRemainingArguments=$true)]$Arguments) }
        if (-not (Get-Command git -CommandType Alias -ErrorAction SilentlyContinue)) {
            Set-Alias -Name git -Value GitMockStub -Scope Global -Option AllScope
        }
    }

    BeforeEach {
        $service = [GitService]::new()
        
        # Default Mocks
        Mock Test-Path { return $true }
        Mock Push-Location { }
        Mock Pop-Location { }
        
        # Default Git Success
        Mock GitMockStub { $global:LASTEXITCODE = 0; return "" }
    }

    Context "Repository Status" {
        It "IsGitRepository returns true when .git exists" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -match "\.git$" }
            $service.IsGitRepository("C:\Repo") | Should -BeTrue
        }

        It "IsGitRepository returns false correctly" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -match "\.git$" }
            $service.IsGitRepository("C:\Repo") | Should -BeFalse
        }

        It "GetCurrentBranch parses rev-parse output" {
            Mock GitMockStub { 
                $global:LASTEXITCODE = 0
                return "feature/test-branch" 
            } -ParameterFilter { $Arguments -contains "rev-parse" }
            
            $service.GetCurrentBranch("C:\Repo") | Should -Be "feature/test-branch"
        }

        It "HasUncommittedChanges detects changes" {
            Mock GitMockStub { 
                $global:LASTEXITCODE = 0
                return "M  file.txt" 
            } -ParameterFilter { $Arguments -contains "status" }
            
            $service.HasUncommittedChanges("C:\Repo") | Should -BeTrue
        }

        It "HasUnpushedCommits detects commits ahead" {
            Mock GitMockStub { 
                $global:LASTEXITCODE = 0
                return "origin/main...HEAD" # rev-parse output
            } -ParameterFilter { $Arguments -contains "rev-parse" }

            Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "commit-hash"
            } -ParameterFilter { $Arguments -contains "log" }
            
            $service.HasUnpushedCommits("C:\Repo") | Should -BeTrue
        }
    }

    Context "Branch Operations" {
        It "GetBranches parses branch list correctly" {
            # --format="%(refname:short)" returns just names, no *
            Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "main", "feature/current", "develop"
            } -ParameterFilter { $Arguments -contains "branch" }

            $branches = $service.GetBranches("C:\Repo")
            $branches.Count | Should -Be 3
            $branches[1] | Should -Be "feature/current"
        }

        It "CreateBranch calls checkout -b" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            
            # Requires 3 arguments: RepoPath, NewBranch, SourceBranch
            $result = $service.CreateBranch("C:\Repo", "new-feature", "main")
            $result.Success | Should -BeTrue
        }

        It "DeleteLocalBranch handles success" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.DeleteLocalBranch("C:\Repo", "old-feature", $false)
            $result.Success | Should -BeTrue
        }

        It "DeleteLocalBranch handles failure" {
            Mock GitMockStub { 
                $global:LASTEXITCODE = 1
                Write-Output "error: branch not found" 
            }
            # Mocking Write-Error might be needed if the service uses it, 
            # but GitService seems to wrap things in OperationResult.
            
            $result = $service.DeleteLocalBranch("C:\Repo", "missing", $false)
            $result.Success | Should -BeFalse
            $result.Message | Should -Match "error"
        }
    }

    Context "Remote Operations" {
        It "Pull returns success on exit code 0" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Pull("C:\Repo")
            $result.Success | Should -BeTrue
        }

        It "Push returns failure on non-zero exit code" {
            Mock GitMockStub { 
                $global:LASTEXITCODE = 1 
                return "fatal: remote error"
            }
            $result = $service.Push("C:\Repo", "main")
            $result.Success | Should -BeFalse
        }
    }


    Context "Git Status Integration" {
        It "GetGitStatus returns full model" {
            Mock Test-Path { return $true }
            
            # Mock IsGitRepository to avoid internal calls failing if using real Test-Path
            # But here we mock Test-Path. 
            
            Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "main"
            } -ParameterFilter { $Arguments -contains "rev-parse" }

            Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "" # No changes
            } -ParameterFilter { $Arguments -contains "status" }
            
            Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "" # No unpushed
            } -ParameterFilter { $Arguments -contains "log" }

            $status = $service.GetGitStatus("C:\Repo")
            $status | Should -Not -BeNull
            $status.CurrentBranch | Should -Be "main"
            $status.HasUncommittedChanges | Should -BeFalse
        }

        It "GetGitStatus handles non-repo" {
            Mock Test-Path { return $false }
            $status = $service.GetGitStatus("C:\NotRepo")
            $status.IsGitRepository | Should -BeFalse
        }
    }

    Context "Repository Operations" {
        It "CloneRepository handles success" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.CloneRepository("https://github.com/User/Repo.git", "C:\Data", "")
            $result.Success | Should -BeTrue
        }

        It "CloneRepository handles invalid URL" {
            $result = $service.CloneRepository("invalid-url", "C:\Data", "")
            $result | Should -Not -BeNull
            $result.Success | Should -BeFalse
            $result.Message | Should -Match "Invalid Git URL"
        }

        It "Checkout handles success" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Checkout("C:\Repo", "develop")
            $result.Success | Should -BeTrue
        }

        It "Merge handles success" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Merge("C:\Repo", "feature/old")
            $result.Success | Should -BeTrue
        }
    }

    Context "Change Management" {
        It "Add stages files" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Add("C:\Repo", ".")
            $result.Success | Should -BeTrue
        }

        It "Commit commits files" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Commit("C:\Repo", "fix: bug")
            $result.Success | Should -BeTrue
        }

        It "Stash stashes changes" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Stash("C:\Repo", "wip")
            $result.Success | Should -BeTrue
        }
        
        It "Stash handles empty message" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Stash("C:\Repo", "")
            $result.Success | Should -BeTrue
        }
    }

    Context "Remote Branch Ops" {
        It "DeleteRemoteBranch handles success" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.DeleteRemoteBranch("C:\Repo", "feature/done")
            $result.Success | Should -BeTrue
        }
        
        It "RemoteBranchExists returns true if found" {
             Mock GitMockStub { $global:LASTEXITCODE = 0 }
             $service.RemoteBranchExists("C:\Repo", "main") | Should -BeTrue
        }
    }
    
    Context "Container and Utils" {
        It "CountContainedRepositories counts correctly" {
             Mock Get-ChildItem {
                 return @(
                     [PSCustomObject]@{ FullName = "C:\Repo\A"; PSIsContainer = $true },
                     [PSCustomObject]@{ FullName = "C:\Repo\B"; PSIsContainer = $true }
                 )
             }
             
             # Mock IsGitRepository logic for these paths to return true for A, false for B
             # But IsGitRepository checks Join-Path .git. 
             # We can mock Test-Path with ParameterFilter
             Mock Test-Path { return $true } -ParameterFilter { $Path -match "A\\.git$" }
             Mock Test-Path { return $false } -ParameterFilter { $Path -match "B\\.git$" }
             
             $service.CountContainedRepositories("C:\Repo") | Should -Be 1
        }
    }


    Context "Tracking Status" {
        It "GetBranchTrackingStatus returns counts" {
             Mock Test-Path { return $true } -ParameterFilter { $Path -match "\.git$" }
             Mock GitMockStub { $global:LASTEXITCODE = 0 } -ParameterFilter { $Arguments -contains "rev-parse" }
             Mock GitMockStub { 
                 $global:LASTEXITCODE = 0
                 return "3`t5" 
             } -ParameterFilter { $Arguments -contains "rev-list" }
             
             $status = $service.GetBranchTrackingStatus("C:\Repo", "main")
             $status.Ahead | Should -Be 3
             $status.Behind | Should -Be 5
        }

        It "GetBranchTrackingStatus handles no upstream" {
             Mock Test-Path { return $true } -ParameterFilter { $Path -match "\.git$" }
             Mock GitMockStub { $global:LASTEXITCODE = 1 } -ParameterFilter { $Arguments -contains "rev-parse" }
             
             $status = $service.GetBranchTrackingStatus("C:\Repo", "feature")
             $status.Ahead | Should -Be 0
             $status.Behind | Should -Be 0
        }
    }

    Context "Additional Remote Ops" {
        It "Fetch handles success" {
            Mock GitMockStub { $global:LASTEXITCODE = 0 }
            $result = $service.Fetch("C:\Repo")
            $result.Success | Should -BeTrue
        }
        
        It "GetRemoteBranches parses list" {
            Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "origin/main", "origin/feature", "origin/HEAD -> origin/main"
            } -ParameterFilter { $Arguments -contains "branch" }
            
            $branches = $service.GetRemoteBranches("C:\Repo")
            $branches.Count | Should -Be 2
            $branches | Should -Contain "origin/main"
            $branches | Should -Not -Contain "origin/HEAD -> origin/main"
        }
    }
    
    Context "URL Utilities" {
        It "GetRemoteUrl retrieves origin url" {
             Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "https://github.com/User/Repo.git"
            } -ParameterFilter { $Arguments -contains "config" }
            
            $service.GetRemoteUrl("C:\Repo") | Should -Be "https://github.com/User/Repo.git"
        }
        
        It "GetRepoUrl sanitizes SSH URL" {
             Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "git@github.com:User/Repo.git"
            }
            $service.GetRepoUrl("C:\Repo") | Should -Be "https://github.com/User/Repo"
        }

        It "GetRepoUrl sanitizes HTTPS .git URL" {
             Mock GitMockStub {
                $global:LASTEXITCODE = 0
                return "https://github.com/User/Repo.git"
            }
            $service.GetRepoUrl("C:\Repo") | Should -Be "https://github.com/User/Repo"
        }
    }

    Context "Container Utilities Extra" {
        It "IsContainerDirectory returns true for non-git folder" {
             Mock Test-Path { return $false } -ParameterFilter { $Path -match "\.git$" }
             $service.IsContainerDirectory("C:\Folder") | Should -BeTrue
        }
        
        It "IsContainerDirectory returns false for git repo" {
             Mock Test-Path { return $true } -ParameterFilter { $Path -match "\.git$" }
             $service.IsContainerDirectory("C:\Repo") | Should -BeFalse
        }
    }

    Context "Not Git Repository Guards" {
        BeforeEach {
            Mock Test-Path { return $false } -ParameterFilter { $Path -match "\.git$" }
        }

        It "Operations fail gracefully when not a repo" {
            $service.GetCurrentBranch("C:\NotRepo") | Should -BeNullOrEmpty
            $service.HasUncommittedChanges("C:\NotRepo") | Should -BeFalse
            $service.GetGitStatus("C:\NotRepo").IsGitRepository | Should -BeFalse
            
            $service.Fetch("C:\NotRepo").Success | Should -BeFalse
            $service.Pull("C:\NotRepo").Success | Should -BeFalse
            $service.Push("C:\NotRepo", "main").Success | Should -BeFalse
            
            $service.Add("C:\NotRepo", ".").Success | Should -BeFalse
            $service.Commit("C:\NotRepo", "msg").Success | Should -BeFalse
            $service.Stash("C:\NotRepo", "msg").Success | Should -BeFalse
            $service.Checkout("C:\NotRepo", "main").Success | Should -BeFalse
            $service.CreateBranch("C:\NotRepo", "new", "main").Success | Should -BeFalse
            $service.DeleteLocalBranch("C:\NotRepo", "branch", $false).Success | Should -BeFalse
            $service.DeleteRemoteBranch("C:\NotRepo", "branch").Success | Should -BeFalse
            $service.GetBranches("C:\NotRepo").Count | Should -Be 0
            $service.GetRemoteBranches("C:\NotRepo").Count | Should -Be 0
        }
    }
}
