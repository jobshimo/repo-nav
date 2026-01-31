BeforeAll {
    . "$PSScriptRoot/../../../../src/Services/SearchService.ps1"
    
    # Mock RepositoryModel for testing
    function New-MockRepo {
        param($Name, $Alias = $null)
        
        $repo = [PSCustomObject]@{
            Name = $Name
            FullPath = "C:\Repos\$Name"
            HasAlias = $false
            AliasInfo = $null
        }
        
        if ($Alias) {
            $repo.HasAlias = $true
            $repo.AliasInfo = [PSCustomObject]@{ Alias = $Alias }
        }
        
        return $repo
    }
}

Describe "SearchService" {
    BeforeAll {
        $service = [SearchService]::new()
        
        $repo1 = New-MockRepo -Name "repo-nav" -Alias "nav"
        $repo2 = New-MockRepo -Name "backend-api"
        $repo3 = New-MockRepo -Name "frontend-ui" -Alias "ui"
        
        $allRepos = @($repo1, $repo2, $repo3)
    }

    Context "FilterRepositories" {
        It "returns empty array if input is null or empty" {
            $result = $service.FilterRepositories($null, "something")
            $result.Count | Should -Be 0
            
            $result = $service.FilterRepositories(@(), "something")
            $result.Count | Should -Be 0
        }

        It "returns all repositories if search text is empty" {
            $result = $service.FilterRepositories($allRepos, "")
            $result.Count | Should -Be 3
            
            $result = $service.FilterRepositories($allRepos, $null)
            $result.Count | Should -Be 3
        }

        It "filters by name case-insensitive" {
            $result = $service.FilterRepositories($allRepos, "BACKEND")
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "backend-api"
        }

        It "filters by alias case-insensitive" {
            $result = $service.FilterRepositories($allRepos, "NAV")
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be "repo-nav"
        }
        
        It "filters partial matches" {
            $result = $service.FilterRepositories($allRepos, "end")
            $result.Count | Should -Be 2 # backEND, frontEND
        }
        
        It "returns empty if no match found" {
            $result = $service.FilterRepositories($allRepos, "xkzjfh")
            $result.Count | Should -Be 0
        }
    }

    Context "FindRepositoryIndex" {
        It "returns correct index for existing repository" {
            $filtered = @($repo2, $repo1) # Simulated filtered list
            
            $index = $service.FindRepositoryIndex($filtered, $repo1)
            $index | Should -Be 1
            
            $index = $service.FindRepositoryIndex($filtered, $repo2)
            $index | Should -Be 0
        }

        It "returns 0 if not found (default safety)" {
            $filtered = @($repo2)
            $index = $service.FindRepositoryIndex($filtered, $repo3)
            $index | Should -Be 0
        }
    }

    Context "FindOriginalIndex" {
        It "returns correct original index" {
            # $allRepos is [repo1, repo2, repo3]
            
            $index = $service.FindOriginalIndex($allRepos, $repo3)
            $index | Should -Be 2
            
            $index = $service.FindOriginalIndex($allRepos, $repo1)
            $index | Should -Be 0
        }

        It "returns -1 if not found" {
            $unknownRepo = New-MockRepo -Name "unknown"
            $index = $service.FindOriginalIndex($allRepos, $unknownRepo)
            $index | Should -Be -1
        }
    }
}
