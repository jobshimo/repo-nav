# tests/Pester/Unit/GitStatusManager.Tests.ps1

Describe "GitStatusManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $testRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load specialized logic if not in Test-Setup (though most are)
        . "$srcRoot\Core\Services\GitStatusManager.ps1"
        
        # Load Mocks
        . "$testRoot\tests\Mocks\MockParallelGitLoader.ps1"
        . "$testRoot\tests\Mocks\MockUserPreferencesService.ps1"
        . "$testRoot\tests\Mocks\MockProgressReporter.ps1"
    }

    Context "Loading Status" {
        BeforeEach {
            $gitService = [GitService]::new()
            $mockParallel = [MockParallelGitLoader]::new()
            $mockPrefs = [MockUserPreferencesService]::new()
            $mockProgress = [MockProgressReporter]::new()
            
            $manager = [GitStatusManager]::new($gitService, $mockParallel, $mockPrefs, $mockProgress)
        }
        
        It "LoadGitStatusForRepos delegates to ParallelLoader" {
            $repo = [RepositoryModel]::new("C:\Test\Repo")
            
            # Should call Parallel (Count = 1)
            $manager.LoadGitStatusForRepos(@($repo), $null, $true)
            
            $mockParallel.CallCount | Should -Be 1
        }
        
        It "LoadGitStatusForRepos filters already loaded if not forced" {
             $repo = [RepositoryModel]::new("C:\Test\Repo")
             # Mark as loaded recently
             $repo.SetGitStatus([GitStatusModel]::new())
             $repo.LastStatusCheck = Get-Date
             
             $manager.LoadGitStatusForRepos(@($repo), $null, $false)
             
             # Should NOT call parallel because it's cached
             $mockParallel.CallCount | Should -Be 0
        }
        
        It "LoadGitStatus hydration updates repo" {
            # Pre-populate cache
            $repoPath = "C:\Test\CachedRepo"
            $cachedStatus = [GitStatusModel]::new()
            $cachedStatus.CurrentBranch = "cached-branch"
            
            $manager.GitStatusCache[$repoPath] = $cachedStatus
            
            # Repo needing hydration
            $repo = [RepositoryModel]::new($repoPath)
            $repo.GitStatus | Should -BeNull
            
            $manager.HydrateFromCache($repo)
            
            $repo.GitStatus | Should -Not -BeNull
            $repo.GitStatus.CurrentBranch | Should -Be "cached-branch"
        }
    }
    
    Context "Auto Load" {
        BeforeEach {
            $gitService = [GitService]::new()
            $mockParallel = [MockParallelGitLoader]::new()
            $mockPrefs = [MockUserPreferencesService]::new()
            $mockProgress = [MockProgressReporter]::new()
            
            $manager = [GitStatusManager]::new($gitService, $mockParallel, $mockPrefs, $mockProgress)
        }
        It "PerformAutoLoadGitStatus calls loader if preference set to All" {
             # Use the new mock method pattern
             $mockPrefs.SetPreference("git", "autoLoadGitStatusMode", "All")
             
             $repo = [RepositoryModel]::new("C:\Test\Repo")
             
             $manager.PerformAutoLoadGitStatus(@($repo))
             
             $mockParallel.CallCount | Should -Be 1
        }
        
        It "PerformAutoLoadGitStatus does nothing if preference is None" {
             $mockPrefs.SetPreference("git", "autoLoadGitStatusMode", "None")
             
             $repo = [RepositoryModel]::new("C:\Test\Repo")
             
             $manager.PerformAutoLoadGitStatus(@($repo))
             
             $mockParallel.CallCount | Should -Be 0
        }
    }
}
