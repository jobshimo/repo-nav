# tests/Pester/Unit/ConfigurationService.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "ConfigurationService" {
    BeforeAll {
        $scriptRoot = $PSScriptRoot
        if (-not $scriptRoot) {
            $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        $projectRoot = (Resolve-Path "$scriptRoot\..\..\..").Path
        
        . "$projectRoot\tests\Test-Setup.ps1" | Out-Null
        . "$projectRoot\tests\Mocks\MockCommonServices.ps1"
    }

    Context "Empty Configuration" {
        It "LoadConfiguration handles missing file" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Remove-Item $tempFile -ErrorAction SilentlyContinue

            $service = [ConfigurationService]::new($tempFile)
            $config = $service.LoadConfiguration()
            
            $config | Should -Not -BeNull
            $config.aliases | Should -BeOfType [PSCustomObject]
            , $config.favorites | Should -BeOfType [System.Array]
            $config.favorites.Count | Should -Be 0
        }

        It "CreateEmptyConfiguration returns correct structure" {
            $service = [ConfigurationService]::new("dummy")
            $empty = $service.CreateEmptyConfiguration()
            
            $empty.aliases | Should -BeOfType [PSCustomObject]
            $empty.favorites.Count | Should -Be 0
        }
    }

    Context "Persistence" {
        BeforeEach {
            $TestDrive = $PSScriptRoot 
            # Pester TestDrive is cleaner but lets use temp file to match old test logic
            $tempFile = [System.IO.Path]::GetTempFileName()
            $service = [ConfigurationService]::new($tempFile)
        }

        AfterEach {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }

        It "Saves and Loads configuration correctly" {
            $testConfig = [PSCustomObject]@{
                aliases = [PSCustomObject]@{
                    'C:\Test' = [PSCustomObject]@{ alias = 'test'; color = 'Red' }
                }
                favorites = @('C:\Fav1', 'C:\Fav2')
            }

            $service.SaveConfiguration($testConfig) | Should -BeTrue
            
            $loaded = $service.LoadConfiguration()
            $loaded.aliases.'C:\Test'.alias | Should -Be 'test'
            $loaded.favorites.Count | Should -Be 2
        }
    }

    Context "Migration and Normalization" {
        It "Normalizes string favorite to array" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $json = @{ aliases = @{}; favorites = 'C:\Single' } | ConvertTo-Json
            $json | Set-Content $tempFile -Encoding UTF8

            $service = [ConfigurationService]::new($tempFile)
            $config = $service.LoadConfiguration()

            , $config.favorites | Should -BeOfType [System.Array]
            $config.favorites.Count | Should -Be 1
            $config.favorites[0] | Should -Be 'C:\Single'

            Remove-Item $tempFile -Force
        }
    }

    Context "Metadata" {
        BeforeEach {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $service = [ConfigurationService]::new($tempFile)
        }

        AfterEach {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }

        It "ConfigurationExists returns true when file exists" {
            $service.ConfigurationExists() | Should -BeTrue
        }

        It "ConfigurationExists returns false when file missing" {
            Remove-Item $tempFile -Force
            $service.ConfigurationExists() | Should -BeFalse
        }

        It "GetConfigurationInfo returns existing file info" {
            "test" | Set-Content $tempFile
            $info = $service.GetConfigurationInfo()
            
            $info.Exists | Should -BeTrue
            $info.Path | Should -Be $tempFile
            $info.Size | Should -BeGreaterThan 0
            $info.LastModified | Should -BeOfType [DateTime]
        }

        It "GetConfigurationInfo returns empty info for missing file" {
            Remove-Item $tempFile -Force
            $info = $service.GetConfigurationInfo()
            
            $info.Exists | Should -BeFalse
            $info.Size | Should -Be 0
            $info.LastModified | Should -BeNull
        }
    }

    Context "Error Handling" {
        BeforeEach {
            $tempFile = [System.IO.Path]::GetTempFileName()
            $service = [ConfigurationService]::new($tempFile)
        }

        AfterEach {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }

        It "LoadConfiguration returns empty config on empty file" {
            "" | Set-Content $tempFile
            $config = $service.LoadConfiguration()
            
            $config | Should -Not -BeNull
            ($null -eq $config.aliases) | Should -BeFalse
            # Check properties count using Get-Member
            ($config.aliases | Get-Member -MemberType NoteProperty).Count | Should -Be 0
        }

        It "LoadConfiguration handles invalid JSON" {
            # Mock Write-Warning to suppress output noise
            Mock Write-Warning { } 
            
            "{ invalid json" | Set-Content $tempFile
            $config = $service.LoadConfiguration()
            
            $config | Should -Not -BeNull
            # Use unary comma to prevent unrolling empty array
            , $config.favorites | Should -BeOfType [System.Array]
            $config.favorites.Count | Should -Be 0
        }
        
        It "LoadConfiguration handles valid JSON with missing properties" {
            "{}" | Set-Content $tempFile
             $config = $service.LoadConfiguration()
             
             ($null -eq $config.aliases) | Should -BeFalse
             ($null -eq $config.favorites) | Should -BeFalse
             , $config.favorites | Should -BeOfType [System.Array]
        }

        It "SaveConfiguration handles write errors gracefully" {
            # Mock Write-Error to prevent Pester failure
            Mock Write-Error { }
            
            # Using invalid characters for path
            $badPath = "C:\InvalidDir\<<>>\||\Config.json"
            $badService = [ConfigurationService]::new($badPath)
            
            $result = $badService.SaveConfiguration(@{})
            $result | Should -BeFalse
        }
    }
}
