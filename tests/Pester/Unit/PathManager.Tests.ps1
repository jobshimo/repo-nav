Describe "PathManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        
        # Load dependencies
        . "$srcRoot\Config\Constants.ps1"
        . "$srcRoot\Services\ArrayHelper.ps1"
        . "$srcRoot\Services\UserPreferencesService.ps1"
        . "$srcRoot\Core\Services\PathManager.ps1"
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
    }
}
