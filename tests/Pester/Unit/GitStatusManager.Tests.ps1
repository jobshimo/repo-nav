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
        
        It "PerformAutoLoadGitStatus loads only favorites when mode is Favorites" {
            $mockPrefs.SetPreference("git", "autoLoadGitStatusMode", "Favorites")
            
            $repo1 = [RepositoryModel]::new("C:\Test\Repo1")
            $repo1.IsFavorite = $true
            $repo2 = [RepositoryModel]::new("C:\Test\Repo2")
            $repo2.IsFavorite = $false
            
            $manager.PerformAutoLoadGitStatus(@($repo1, $repo2))
            
            $mockParallel.CallCount | Should -Be 1
        }
        
        It "PerformAutoLoadGitStatus returns early if PreferencesService is null" {
            $manager2 = [GitStatusManager]::new($gitService, $mockParallel, $null, $mockProgress)
            
            $repo = [RepositoryModel]::new("C:\Test\Repo")
            $manager2.PerformAutoLoadGitStatus(@($repo))
            
            $mockParallel.CallCount | Should -Be 0
        }
        
        It "PerformAutoLoadGitStatus defaults to None when mode is not set" {
            # Don't set any preference
            $repo = [RepositoryModel]::new("C:\Test\Repo")
            
            $manager.PerformAutoLoadGitStatus(@($repo))
            
            $mockParallel.CallCount | Should -Be 0
        }
        
        It "PerformAutoLoadGitStatus skips already loaded repos in All mode" {
            $mockPrefs.SetPreference("git", "autoLoadGitStatusMode", "All")
            
            $repo1 = [RepositoryModel]::new("C:\Test\Repo1")
            $repo2 = [RepositoryModel]::new("C:\Test\Repo2")
            $repo2.SetGitStatus([GitStatusModel]::new())
            $repo2.LastStatusCheck = Get-Date
            
            $manager.PerformAutoLoadGitStatus(@($repo1, $repo2))
            
            # Should call but only with 1 repo
            $mockParallel.CallCount | Should -Be 1
        }
    }
    
    Context "LoadGitStatus Single Repo" {
        BeforeEach {
            $gitService = [GitService]::new()
            $mockParallel = [MockParallelGitLoader]::new()
            $mockPrefs = [MockUserPreferencesService]::new()
            $mockProgress = [MockProgressReporter]::new()
            
            $manager = [GitStatusManager]::new($gitService, $mockParallel, $mockPrefs, $mockProgress)
        }
        
        It "LoadGitStatus skips containers" {
            $repo = [RepositoryModel]::new("C:\Test\Container")
            $repo.IsContainer = $true
            
            $manager.LoadGitStatus($repo, $false)
            
            # Should not cache anything
            $manager.GitStatusCache.Count | Should -Be 0
        }
        
        It "LoadGitStatus uses cache when not forced and recently checked" {
            $repo = [RepositoryModel]::new("C:\Test\Repo")
            $repo.SetGitStatus([GitStatusModel]::new())
            $repo.LastStatusCheck = Get-Date
            
            $manager.LoadGitStatus($repo, $false)
            
            # Repo should still have its status (didn't reload)
            $repo.GitStatus | Should -Not -BeNull
        }
        
        It "LoadGitStatus forces reload when forced is true" {
            $repo = [RepositoryModel]::new("C:\Test\Repo")
            $repo.SetGitStatus([GitStatusModel]::new())
            $repo.LastStatusCheck = Get-Date
            
            $manager.LoadGitStatus($repo, $true)
            
            # Should have cached the status
            $manager.GitStatusCache.ContainsKey($repo.FullPath) | Should -BeTrue
        }
    }
    
    Context "HydrateFromCache" {
        BeforeEach {
            $gitService = [GitService]::new()
            $mockParallel = [MockParallelGitLoader]::new()
            $mockPrefs = [MockUserPreferencesService]::new()
            $mockProgress = [MockProgressReporter]::new()
            
            $manager = [GitStatusManager]::new($gitService, $mockParallel, $mockPrefs, $mockProgress)
        }
        
        It "HydrateFromCache does nothing when repo not in cache" {
            $repo = [RepositoryModel]::new("C:\Test\NotCached")
            
            $manager.HydrateFromCache($repo)
            
            $repo.GitStatus | Should -BeNull
        }
    }
    
    Context "LoadGitStatusForRepos Edge Cases" {
        BeforeEach {
            $gitService = [GitService]::new()
            $mockParallel = [MockParallelGitLoader]::new()
            $mockPrefs = [MockUserPreferencesService]::new()
            $mockProgress = [MockProgressReporter]::new()
            
            $manager = [GitStatusManager]::new($gitService, $mockParallel, $mockPrefs, $mockProgress)
        }
        
        It "LoadGitStatusForRepos returns early when no repos to load" {
            $manager.LoadGitStatusForRepos(@(), $null, $false)
            
            $mockParallel.CallCount | Should -Be 0
        }
        
        It "LoadGitStatusForRepos filters containers" {
            $repo1 = [RepositoryModel]::new("C:\Test\Repo")
            $repo2 = [RepositoryModel]::new("C:\Test\Container")
            $repo2.IsContainer = $true
            
            $manager.LoadGitStatusForRepos(@($repo1, $repo2), $null, $true)
            
            # Should call with only 1 repo (non-container)
            $mockParallel.CallCount | Should -Be 1
        }
    }
}
