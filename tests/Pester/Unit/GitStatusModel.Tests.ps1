using module "..\..\TestHelper.psm1"

Describe "GitStatusModel" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Models\GitStatusModel.ps1"
    }

    Context "Constructors" {
        It "Default constructor initializes empty state" {
            $status = [GitStatusModel]::new()
            $status.IsGitRepo | Should -BeFalse
            $status.CurrentBranch | Should -BeNullOrEmpty
        }

        It "Full constructor initializes properties" {
            $status = [GitStatusModel]::new($true, $true, $false, "feature/test")
            $status.IsGitRepo | Should -BeTrue
            $status.HasUncommittedChanges | Should -BeTrue
            $status.HasUnpushedCommits | Should -BeFalse
            $status.CurrentBranch | Should -Be "feature/test"
        }
    }

    Context "State Checkers" {
        It "IsClean returns true when nothing pending" {
            $status = [GitStatusModel]::new($true, $false, $false, "main")
            $status.IsClean() | Should -BeTrue
            $status.NeedsAttention() | Should -BeFalse
        }

        It "IsClean returns false when uncommitted changes exist" {
            $status = [GitStatusModel]::new($true, $true, $false, "main")
            $status.IsClean() | Should -BeFalse
        }

        It "NeedsAttention returns true when unpushed commits exist" {
            $status = [GitStatusModel]::new($true, $false, $true, "main")
            $status.NeedsAttention() | Should -BeTrue
        }
    }

    Context "Priority Logic" {
        It "GetPriority returns 0 for non-git" {
            $status = [GitStatusModel]::new()
            $status.GetPriority() | Should -Be 0
        }

        It "GetPriority returns 3 for uncommitted changes" {
            $status = [GitStatusModel]::new($true, $true, $false, "main")
            $status.GetPriority() | Should -Be 3
        }

        It "GetPriority returns 2 for unpushed commits" {
            $status = [GitStatusModel]::new($true, $false, $true, "main")
            $status.GetPriority() | Should -Be 2
        }

        It "GetPriority returns 1 for clean repo" {
            $status = [GitStatusModel]::new($true, $false, $false, "main")
            $status.GetPriority() | Should -Be 1
        }
    }

    Context "ToString" {
        It "Formats string correctly for dirty repo" {
            $status = [GitStatusModel]::new($true, $true, $false, "dev")
            $str = $status.ToString()
            $str | Should -Match "Branch: dev"
            $str | Should -Match "\[Uncommitted\]"
        }
    }
}
