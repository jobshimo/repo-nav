# tests/Pester/Unit/ConfigurationService.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "ConfigurationService" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize("$srcRoot\..")
        . "$srcRoot\Services\ConfigurationService.ps1"
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
}
