# tests/Pester/Unit/LocalizationService.Tests.ps1

Describe "LocalizationService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\Constants.ps1"
        [Constants]::Initialize("$srcRoot\..")
        . "$srcRoot\Core\Interfaces\ILocalizationService.ps1"
        . "$srcRoot\Services\LocalizationService.ps1"
    }

    BeforeEach {
        $resourcesPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
        New-Item -Path $resourcesPath -ItemType Directory -Force | Out-Null
        
        # Create English (fallback)
        $en = @{
            "Test.Key" = "English Value"
            "Test.Format" = "Hello {0}!"
        }
        $en | ConvertTo-Json | Set-Content (Join-Path $resourcesPath "en.json") -Encoding UTF8
        
        # Create Spanish
        $es = @{
            "Test.Key" = "Valor en Español"
        }
        $es | ConvertTo-Json | Set-Content (Join-Path $resourcesPath "es.json") -Encoding UTF8
        
        # Store for cleanup
        $script:tempResources = $resourcesPath
        
        # Instantiate service and point to temp resources
        # We need to hack the ResourcesPath because it's hardcoded in the constructor
        $service = [LocalizationService]::new()
        $service.ResourcesPath = $resourcesPath
        
        # Reload to pick up temp files
        $service.LoadFallback()
        $service.LoadLanguage("en")
        
        $script:service = $service
    }

    AfterEach {
        if (Test-Path $script:tempResources) {
            Remove-Item $script:tempResources -Recurse -Force
        }
    }

    Context "Default Behavior" {
        It "Returns English value by default" {
            $script:service.Get("Test.Key") | Should -Be "English Value"
        }

        It "Returns [key] for missing keys" {
            $script:service.Get("Missing.Key") | Should -Be "[Missing.Key]"
        }
    }

    Context "Language Switching" {
        It "Loads Spanish correctly" {
            $script:service.SetLanguage("es")
            $script:service.Get("Test.Key") | Should -Be "Valor en Español"
        }

        It "Falls back to English if key missing in Spanish" {
            $script:service.SetLanguage("es")
            $script:service.Get("Test.Format") | Should -Be "Hello {0}!"
        }
    }

    Context "String Formatting" {
        It "Formats strings with arguments" {
            $script:service.Get("Test.Format", @("World")) | Should -Be "Hello World!"
        }

        It "Returns raw string if no arguments provided" {
            $script:service.Get("Test.Format") | Should -Be "Hello {0}!"
        }
        
        It "Handles formatting errors gracefully" {
            # Provide wrong number of args or invalid format
            $script:service.Get("Test.Format", $null) | Should -Be "Hello {0}!"
        }
    }
    
    Context "Utility Methods" {
        It "Returns current language" {
            $script:service.GetCurrentLanguage() | Should -Be "en"
            $script:service.SetLanguage("es")
            $script:service.GetCurrentLanguage() | Should -Be "es"
        }

        It "Lists available languages" {
            $langs = $script:service.GetAvailableLanguages()
            $langs | Should -Contain "en"
            $langs | Should -Contain "es"
        }
    }
}
