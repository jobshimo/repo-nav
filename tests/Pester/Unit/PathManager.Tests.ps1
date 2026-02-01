Describe "PathManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        
        # Load dependencies
        # Load dependencies
        . "$srcRoot\..\tests\Test-Setup.ps1"
    }

    BeforeEach {
        # Setup temporary preferences file
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # Create initial JSON content
        $initialPrefs = @{
            repository = @{
                defaultPath = ""
                paths = @()
            }
        }
        $initialPrefs | ConvertTo-Json -Depth 5 | Set-Content $tempFile

        # Instantiate service with temp file
        $prefsService = [UserPreferencesService]::new($tempFile)
        
        # Instantiate System Under Test
        $pathManager = [PathManager]::new($prefsService)
        
        # Store for cleanup
        $script:tempFile = $tempFile
    }

    AfterEach {
        if (Test-Path $script:tempFile) {
            Remove-Item $script:tempFile -Force
        }
    }

    Context "Initialization" {
        It "Initializes with empty cache when no default path set" {
            $pathManager.GetCurrentPath() | Should -BeNullOrEmpty
        }
    }

    Context "Path Management" {
        It "AddPath adds path to preferences" {
            # Mock Resolve-Path to avoid disk dependency issues or use existing temp dir
            $tempDir = [System.IO.Path]::GetTempPath()
            
            $result = $pathManager.AddPath($tempDir)
            
            $result | Should -BeTrue
            $pathManager.GetAllPaths() | Should -Contain $tempDir
        }
        
        It "SetCurrentPath updates cache and preferences" {
            $tempDir = [System.IO.Path]::GetTempPath()
            $pathManager.SetCurrentPath($tempDir)
            
            $pathManager.GetCurrentPath() | Should -Be $tempDir
            
            # Verify persistence
            $savedPrefs = $prefsService.LoadPreferences()
            $savedPrefs.repository.defaultPath | Should -Be $tempDir
        }
        
        It "RemovePath removes path from list" {
            $tempDir = [System.IO.Path]::GetTempPath()
            $pathManager.AddPath($tempDir)
            
            $pathManager.GetAllPaths() | Should -Contain $tempDir
            
            $pathManager.RemovePath($tempDir)
            
            $pathManager.GetAllPaths() | Should -Not -Contain $tempDir
        }

        It "RemovePath updates defaultPath if removed path was default" {
            $dir1 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "dir1")
            $dir2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "dir2")
            New-Item -Path $dir1, $dir2 -ItemType Directory -Force | Out-Null
            
            try {
                $pathManager.AddPath($dir1)
                $pathManager.AddPath($dir2)
                $pathManager.SetCurrentPath($dir1)
                
                $pathManager.RemovePath($dir1)
                
                $pathManager.GetCurrentPath() | Should -Be $dir2
            }
            finally {
                Remove-Item $dir1, $dir2 -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "GetAllPaths returns empty array instead of null" {
            $pathManager.GetAllPaths().Count | Should -Be 0
        }

        It "HasPaths returns correct status" {
            $pathManager.HasPaths() | Should -BeFalse
            $pathManager.AddPath([System.IO.Path]::GetTempPath())
            $pathManager.HasPaths() | Should -BeTrue
        }
        
        It "Refresh syncs cache from preferences" {
            $tempDir = [System.IO.Path]::GetTempPath()
            # Manually update underlying preference without using PathManager
            $prefsService.SetPreference("repository", "defaultPath", $tempDir)
            
            $pathManager.GetCurrentPath() | Should -Not -Be $tempDir
            $pathManager.Refresh()
            $pathManager.GetCurrentPath() | Should -Be $tempDir
        }
    }
}
