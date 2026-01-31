using module "..\..\TestHelper.psm1"

Describe "RepositoryModel" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        
        # Config (Required by AliasInfo)
        . "$srcRoot\Config\Constants.ps1"
        . "$srcRoot\Config\ColorPalette.ps1"
        
        # Models
        . "$srcRoot\Models\AliasInfo.ps1"
        . "$srcRoot\Models\GitStatusModel.ps1"
        . "$srcRoot\Models\RepositoryModel.ps1"
    }

    Context "Constructor" {
        It "Initializes from DirectoryInfo correctly" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Projects\MyRepo")
            $model = [RepositoryModel]::new($dirInfo)

            $model.Name | Should -Be "MyRepo"
            $model.FullPath | Should -Be "C:\Projects\MyRepo"
            $model.HasAlias | Should -BeFalse
            $model.IsFavorite | Should -BeFalse
        }
    }

    Context "Alias Management" {
        It "SetAlias sets correct flags" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $alias = [AliasInfo]::new("my-alias", "red")
            $model.SetAlias($alias)

            $model.HasAlias | Should -BeTrue
            $model.AliasInfo.Alias | Should -Be "my-alias"
        }

        It "RemoveAlias clears flags" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            $alias = [AliasInfo]::new("my-alias", "red")
            $model.SetAlias($alias)
            
            $model.RemoveAlias()

            $model.HasAlias | Should -BeFalse
            $model.AliasInfo | Should -BeNull
        }
    }

    Context "Feature Flags" {
        BeforeEach {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
        }

        It "MarkAsHidden sets flag" {
            $model.MarkAsHidden($true)
            $model.IsHidden | Should -BeTrue
        }

        It "MarkAsFavorite sets flag" {
            $model.MarkAsFavorite($true)
            $model.IsFavorite | Should -BeTrue
        }

        It "MarkAsContainer sets flags and count" {
            $model.MarkAsContainer(5)
            $model.IsContainer | Should -BeTrue
            $model.ContainedRepoCount | Should -Be 5
            $model.IsContainerFolder() | Should -BeTrue
        }
    }

    Context "Git Integration" {
        It "SetGitStatus updates status" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $status = [GitStatusModel]::new($true, $false, $false, "main")
            $model.SetGitStatus($status)

            $model.GitStatus | Should -Not -BeNull
            $model.HasGitStatusLoaded() | Should -BeTrue
        }
        
        It "HasGitStatusLoaded returns false when status is null" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $model.HasGitStatusLoaded() | Should -BeFalse
        }
    }
    
    Context "Node.js Integration" {
        It "CheckNodeModules detects node_modules folder" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\RepoWithNode")
            $model = [RepositoryModel]::new($dirInfo)
            
            Mock Test-Path { 
                param($Path)
                return $Path -like "*node_modules"
            }
            
            $model.CheckNodeModules()
            $model.HasNodeModules | Should -BeTrue
        }
        
        It "CheckNodeModules sets false when no node_modules" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\RepoNoNode")
            $model = [RepositoryModel]::new($dirInfo)
            
            Mock Test-Path { return $false }
            
            $model.CheckNodeModules()
            $model.HasNodeModules | Should -BeFalse
        }
        
        It "HasPackageJson detects package.json file" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\RepoWithPackage")
            $model = [RepositoryModel]::new($dirInfo)
            
            Mock Test-Path { 
                param($Path)
                return $Path -like "*package.json"
            }
            
            $model.HasPackageJson() | Should -BeTrue
        }
        
        It "HasPackageJson returns false when no package.json" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\RepoNoPackage")
            $model = [RepositoryModel]::new($dirInfo)
            
            Mock Test-Path { return $false }
            
            $model.HasPackageJson() | Should -BeFalse
        }
    }
    
    Context "Hierarchy" {
        It "SetParentPath sets parent path correctly" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $model.SetParentPath("C:\Path")
            $model.ParentPath | Should -Be "C:\Path"
        }
    }

    Context "ToString" {
        It "Returns string representation correctly" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $str = $model.ToString()
            $str | Should -Match "Repo"
        }
        
        It "ToString includes container info" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Container")
            $model = [RepositoryModel]::new($dirInfo)
            $model.MarkAsContainer(3)
            
            $str = $model.ToString()
            $str | Should -Match "CONTAINER"
            $str | Should -Match "3 repos"
        }
        
        It "ToString includes alias info" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            $alias = [AliasInfo]::new("my-alias", "red")
            $model.SetAlias($alias)
            
            $str = $model.ToString()
            $str | Should -Match "Alias:"
            $str | Should -Match "my-alias"
        }
        
        It "ToString includes favorite marker" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            $model.MarkAsFavorite($true)
            
            $str = $model.ToString()
            $str | Should -Match "\[FAV\]"
        }
        
        It "ToString includes git status" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            $status = [GitStatusModel]::new($true, $true, $false, "main")
            $model.SetGitStatus($status)
            
            $str = $model.ToString()
            $str | Should -Match "Git:"
        }
    }
    
    Context "SetAlias Edge Cases" {
        It "SetAlias does nothing when alias is invalid" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            # Create an invalid alias (no alias text)
            $invalidAlias = [AliasInfo]::new("", "red")
            $model.SetAlias($invalidAlias)
            
            $model.HasAlias | Should -BeFalse
        }
        
        It "SetAlias does nothing when alias is null" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $model.SetAlias($null)
            
            $model.HasAlias | Should -BeFalse
        }
    }
}
