
Describe "RepositoryManager" {
    BeforeAll {
        . "$PSScriptRoot\..\..\Test-Setup.ps1"
        . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
        . "$PSScriptRoot\..\..\Mocks\RepositoryManagerTestMocks.ps1"
    }

    Context "DeleteRepository" {
        It "Removes favorite using FullPath when deleting repository" {
            # Arrange
            $mockGitService = [MockGitService]::new()
            $mockRead = [MockGitService]::new() # Interface compat hack if needed, or null
            $mockWrite = [MockGitWriteService]::new()
            $mockNpm = [MockNpmService]::new()
            $mockAlias = [MockAliasManager]::new()
            $mockPrefs = [MockUserPreferencesService]::new()
            
            # Critical: Mock Favorite Service to verify call
            $mockFav = [MockFavoriteService]::new()
            # We need to spy on RemoveFavorite. Pester Spy is hard with classes in PS5
            # So we rely on MockFavoriteService implementation or override it here?
            
            # Custom Mock for this test to capture calls
            $mockFav = [MockFavoriteServiceSpy]::new()
            
            $mockLoader = [MockParallelGitLoader]::new()
            $mockOps = [MockRepositoryOperationsService]::new()
            $mockProgress = [MockProgressIndicator]::new()
            $mockStatus = [MockGitStatusManager]::new()
            $mockSorter = [RepositorySorter]::new()
            $mockHidden = [MockHiddenReposService]::new()
            
            # Instantiate SUT
            $repoManager = [RepositoryManager]::new(
                $mockGitService,
                $null, # Read
                $mockWrite,
                $mockNpm,
                $mockAlias,
                $mockPrefs,
                $mockFav,
                $mockLoader,
                $mockOps,
                $mockProgress,
                $mockStatus,
                $mockSorter,
                $mockHidden
            )
            
            # Setup Repo
            $repoPath = "C:\Repos\TestRepo"
            $repo = [RepositoryModel]::new($repoPath)
            $repo.Name = "TestRepo"
            $repo.MarkAsFavorite($true)
            
            # Add to manager
            $repoManager.Repositories.Add($repo)
            
            # Act
            $result = $repoManager.DeleteRepository($repo)
            
            # Assert
            $result.Success | Should -BeTrue
            $mockFav.RemoveCalledWith | Should -Be $repoPath
        }
    }
}


