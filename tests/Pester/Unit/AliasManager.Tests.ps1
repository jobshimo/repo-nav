
# tests/Pester/Unit/AliasManager.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "AliasManager" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize("$srcRoot\..")
        . "$srcRoot\Models\_index.ps1"
        . "$srcRoot\Services\ConfigurationService.ps1"
        . "$srcRoot\Services\AliasManager.ps1"
        
        # Load Mocks
        . "$srcRoot\..\tests\Mocks\MockConfigurationService.ps1"
    }

    Context "Alias Operations" {
        BeforeEach {
            # Use MockConfigurationService (SOLID - Liskov Substitution)
            $mockConfig = [MockConfigurationService]::new()
            $aliasManager = [AliasManager]::new($mockConfig)
        }
        
        It "Can be instantiated" {
            $aliasManager | Should -Not -BeNullOrEmpty
        }
        
        It "SetAlias adds an alias to configuration" {
             $aliasInfo = [AliasInfo]::new("TestAlias", "Blue")
             $path = "C:\Test\Repo"
             
             $result = $aliasManager.SetAlias($path, $aliasInfo)
             
             $result | Should -BeTrue
             $mockConfig.SaveCallCount | Should -Be 1
             
             # Verify it was added to mock config
             $aliases = $mockConfig.LoadConfiguration().aliases
             $aliases.Count | Should -Be 1
             $aliases[0].alias | Should -Be "TestAlias"
             $aliases[0].path | Should -Be $path
        }
    }
}
