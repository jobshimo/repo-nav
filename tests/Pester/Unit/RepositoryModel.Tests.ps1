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
    }

    Context "ToString" {
        It "Returns string representation correctly" {
            $dirInfo = [System.IO.DirectoryInfo]::new("C:\Path\Repo")
            $model = [RepositoryModel]::new($dirInfo)
            
            $str = $model.ToString()
            $str | Should -Match "Repo"
        }
    }
}
