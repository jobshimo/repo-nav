# tests/Pester/Integration/SystemLoad.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "System Integration Loading" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        $scriptRoot = $PSScriptRoot
        $testRoot = Resolve-Path "$scriptRoot\..\..\.."
        
        # Use Test-Setup for reliable loading
        . "$testRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Load AppBuilder specifically if not part of Test-Setup (it ends at Startup layer usually)
        # Test-Setup loads "Startup\_index.ps1" which loads ServiceRegistry.
        # Check if AppBuilder needs explicit load or if it's in Startup?
        # App/AppBuilder.ps1 is typically the entry point.
        . "$srcRoot\App\AppBuilder.ps1"
    }

    Context "AppBuilder Construction" {
        It "Builds Application Context successfully" {
            $mockPath = "C:\Test\Repo"
            # Mock Test-Path for the base path if AppBuilder checks it?
            # AppBuilder calls ServiceRegistry::Reset()
            
            # We assume user preferences might exist or not.
            # AppBuilder internal Build:
            # 1. Config Service
            # ...
            # 7. Compose Context
            
            $context = [AppBuilder]::Build($mockPath)
            $context | Should -Not -BeNullOrEmpty
            $context.RepoManager | Should -Not -BeNullOrEmpty
            $context.GitService | Should -BeNullOrEmpty # Context doesn't expose GitService directly, it's in Registry
            
            $gitService = [ServiceRegistry]::Resolve('GitService')
            $gitService | Should -Not -BeNullOrEmpty
        }
    }
}
