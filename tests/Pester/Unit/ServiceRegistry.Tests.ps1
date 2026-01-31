# tests/Pester/Unit/ServiceRegistry.Tests.ps1

Describe "ServiceRegistry" {
    BeforeAll {
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Startup\ServiceRegistry.ps1"
    }

    BeforeEach {
        [ServiceRegistry]::Reset()
    }

    Context "Register and Resolve" {
        It "Registers and resolves a service" {
            $testService = [PSCustomObject]@{ Name = "Test" }
            [ServiceRegistry]::Register("TestService", $testService)
            
            $resolved = [ServiceRegistry]::Resolve("TestService")
            $resolved | Should -Not -BeNull
            $resolved.Name | Should -Be "Test"
        }

        It "Overwrites existing service with same key" {
            $service1 = [PSCustomObject]@{ Value = 1 }
            $service2 = [PSCustomObject]@{ Value = 2 }
            
            [ServiceRegistry]::Register("Service", $service1)
            [ServiceRegistry]::Register("Service", $service2)
            
            $resolved = [ServiceRegistry]::Resolve("Service")
            $resolved.Value | Should -Be 2
        }

        It "Returns null for non-existent service" {
            $resolved = [ServiceRegistry]::Resolve("NonExistent")
            $resolved | Should -BeNull
        }
    }

    Context "Resolve by Type" {
        It "Resolves service by type name" {
            $testService = [PSCustomObject]@{ Data = "TypedData" }
            $typeName = [PSCustomObject].Name
            [ServiceRegistry]::Register($typeName, $testService)
            
            $resolved = [ServiceRegistry]::Resolve([PSCustomObject])
            $resolved | Should -Not -BeNull
            $resolved.Data | Should -Be "TypedData"
        }

        It "Returns null for non-existent type" {
            $resolved = [ServiceRegistry]::Resolve([System.Text.StringBuilder])
            $resolved | Should -BeNull
        }
    }

    Context "Reset" {
        It "Clears all services" {
            [ServiceRegistry]::Register("Service1", "Value1")
            [ServiceRegistry]::Register("Service2", "Value2")
            
            [ServiceRegistry]::Reset()
            
            [ServiceRegistry]::Resolve("Service1") | Should -BeNull
            [ServiceRegistry]::Resolve("Service2") | Should -BeNull
        }
    }
}
