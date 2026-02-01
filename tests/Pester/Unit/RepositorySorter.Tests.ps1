Describe "RepositorySorter" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        
        # Dependencies
        . "$srcRoot\Core\Services\RepositorySorter.ps1"
        
        # Test Double for RepositoryModel (using PSObject since method access isn't required for sorting props)
        # Note: Sort-Object works on PSObjects fine, but the function signature expects ArrayList.
        # However, PowerShell is loose with arrays. But Sort expects RepositoryModel properties 'IsFavorite' and 'Name'.
    }

    Context "Sort Logic" {
        BeforeEach {
            $sorter = [RepositorySorter]::new()
            
            # Create dummy repos
            $repoA = [PSCustomObject]@{ Name = "Apple"; IsFavorite = $false }
            $repoB = [PSCustomObject]@{ Name = "Banana"; IsFavorite = $true }
            $repoC = [PSCustomObject]@{ Name = "Cherry"; IsFavorite = $false }
            
            $list = [System.Collections.ArrayList]::new()
            $null = $list.Add($repoA)
            $null = $list.Add($repoB)
            $null = $list.Add($repoC)
            
            $script:list = $list
        }

        It "Sorts alphabetically when favoritiesOnTop is false" {
            $sorter = [RepositorySorter]::new()
            $sorted = $sorter.Sort($script:list, $false)
            
            $sorted[0].Name | Should -Be "Apple"
            $sorted[1].Name | Should -Be "Banana"
            $sorted[2].Name | Should -Be "Cherry"
        }

        It "Sorts favorites first when favoritiesOnTop is true" {
            $sorter = [RepositorySorter]::new()
            $sorted = $sorter.Sort($script:list, $true)
            
            $sorted[0].Name | Should -Be "Banana" # Favorite
            $sorted[1].Name | Should -Be "Apple"  # Alphabetical rest
            $sorted[2].Name | Should -Be "Cherry"
        }

        It "Handles null repository list gracefully" {
            $sorter = [RepositorySorter]::new()
            $sorted = $sorter.Sort($null, $true)
            $sorted.Count | Should -Be 0
        }

        It "Handles empty repository list gracefully" {
            $sorter = [RepositorySorter]::new()
            $emptyList = [System.Collections.ArrayList]::new()
            $sorted = $sorter.Sort($emptyList, $true)
            $sorted.Count | Should -Be 0
        }
    }
}
