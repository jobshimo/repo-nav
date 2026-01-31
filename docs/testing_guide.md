# Guía de Testing con Interfaces

**Fecha:** 31 de Enero de 2026  
**Autor:** Desarrollo Repo-Nav  
**Propósito:** Guía práctica para escribir tests siguiendo SOLID y el patrón de interfaces

## Introducción

Esta guía explica cómo escribir tests correctos en el proyecto `repo-nav` después de la implementación completa de interfaces. Todos los tests DEBEN seguir estos patrones para garantizar compatibilidad y mantenibilidad.

## Patrón Base para Tests

### 1. Estructura de un Test

```powershell
Describe "Mi Componente" {
    BeforeAll {
        # ───────────────────────────────────────────────────────────────
        # PASO 1: Cargar el entorno completo
        # ───────────────────────────────────────────────────────────────
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        . "$scriptRoot\tests\Test-Setup.ps1" | Out-Null
        
        # ───────────────────────────────────────────────────────────────
        # PASO 2: Cargar mocks reutilizables
        # ───────────────────────────────────────────────────────────────
        . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
        . "$PSScriptRoot\..\..\Mocks\MockRepositoryManager.ps1"
        
        # ───────────────────────────────────────────────────────────────
        # PASO 3: Definir mocks específicos del test
        # ───────────────────────────────────────────────────────────────
        $localMocks = @'
        class MockMiClaseEspecifica : IMiInterfaz {
            [string] MiMetodo([string]$param) { return "mock" }
        }
'@
        Invoke-Expression $localMocks
        
        # ───────────────────────────────────────────────────────────────
        # PASO 4: Cargar mocks comunes (de MockCommonServices.ps1)
        # ───────────────────────────────────────────────────────────────
        Invoke-Expression $global:MockServiceDefinitions
    }
    
    Context "Escenario específico" {
        BeforeEach {
            # Setup de objetos para cada test
            $mockService = New-Object MockMiClaseEspecifica
            # ... más setup
        }
        
        It "Debe hacer algo" {
            # Test aquí
        }
    }
}
```

## Reglas Fundamentales

### ❌ PROHIBIDO

1. **NO instanciar clases concretas en tests**
   ```powershell
   # ❌ MAL
   $console = [ConsoleHelper]::new()
   $renderer = [UIRenderer]::new($console, $null)
   ```

2. **NO usar PSCustomObject para propiedades tipadas**
   ```powershell
   # ❌ MAL - No funciona con propiedades tipadas
   $mockConsole = [PSCustomObject]@{}
   $mockConsole | Add-Member -MemberType ScriptMethod -Name "Clear" -Value {} -Force
   $context.Console = $mockConsole  # ❌ Error: Cannot convert PSCustomObject to IConsoleHelper
   ```

3. **NO redefinir clases reales**
   ```powershell
   # ❌ MAL - Causa conflictos de tipos
   class UIRenderer {
       [void] Render() { }  # Mock que sobreescribe la clase real
   }
   ```

### ✅ CORRECTO

1. **Usar mocks que heredan de interfaces**
   ```powershell
   # ✅ BIEN
   class MockConsoleHelper : IConsoleHelper {
       [void] Clear() {}
       [void] WriteLine([string]$text) {}
       # ... implementar TODOS los métodos de la interfaz
   }
   $mockConsole = New-Object MockConsoleHelper
   ```

2. **Usar los mocks reutilizables de MockCommonServices.ps1**
   ```powershell
   # ✅ BIEN
   . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
   Invoke-Expression $global:MockServiceDefinitions
   
   $mockNpm = New-Object MockNpmService
   $mockConsole = New-Object MockConsoleHelper
   $mockRenderer = New-Object MockUIRenderer
   ```

3. **Registrar servicios en ServiceRegistry cuando sea necesario**
   ```powershell
   # ✅ BIEN
   $mockNpmService = New-Object MockNpmService
   [ServiceRegistry]::Register('NpmService', $mockNpmService)
   ```

## Mocks Disponibles

### En MockCommonServices.ps1

Todos estos mocks están listos para usar:

- `MockNpmService` → `INpmService`
- `MockJobService` → `IJobService`
- `MockConsoleHelper` → `IConsoleHelper`
- `MockUIRenderer` → `IUIRenderer`
- `MockGitService` → `IGitService`
- `MockAliasManager` → `IAliasManager`
- `MockFavoriteService` → `IFavoriteService`
- `MockSearchService` → `ISearchService`
- `MockLoggerService` → `ILoggerService`
- `MockLocalizationService` → `ILocalizationService`

### Cómo usar los mocks

```powershell
BeforeAll {
    # Cargar mocks
    . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
    Invoke-Expression $global:MockServiceDefinitions
}

Context "Mi test" {
    BeforeEach {
        # Instanciar los que necesites
        $mockConsole = New-Object MockConsoleHelper
        $mockNpm = New-Object MockNpmService
        $mockJob = New-Object MockJobService
        
        # Registrar en ServiceRegistry si el código lo busca ahí
        [ServiceRegistry]::Register('NpmService', $mockNpm)
        [ServiceRegistry]::Register('JobService', $mockJob)
    }
}
```

## Ejemplo Completo

```powershell
Describe "NavigationCommand Tests" {
    BeforeAll {
        # Cargar entorno
        . "$PSScriptRoot\..\..\..\tests\Test-Setup.ps1" | Out-Null
        
        # Cargar mocks comunes
        . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
        . "$PSScriptRoot\..\..\Mocks\MockRepositoryManager.ps1"
        
        # Mock específico para NavigationState (hereda de clase base)
        $customMock = @'
        class MockNavigationState : NavigationState {
            [array] $Repos = @()
            [int] $CurrentIndex = 0
            
            MockNavigationState() : base(@()) {}
            
            [void] SetRepositories([array]$repos) { $this.Repos = $repos }
            [array] GetRepositories() { return $this.Repos }
            [int] GetCurrentIndex() { return $this.CurrentIndex }
        }
'@
        Invoke-Expression $customMock
        
        # Cargar mocks comunes
        Invoke-Expression $global:MockServiceDefinitions
    }
    
    Context "Cuando se ejecuta un comando" {
        BeforeEach {
            # Setup de objetos mock
            $mockConsole = New-Object MockConsoleHelper
            $mockRenderer = New-Object MockUIRenderer
            $mockState = New-Object MockNavigationState
            $mockRepoManager = New-Object MockRepositoryManager
            
            # Configurar estado
            $repo = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\Test"))
            $mockState.SetRepositories(@($repo))
            
            # Crear contexto
            $context = New-Object CommandContext
            $context.Console = $mockConsole
            $context.Renderer = $mockRenderer
            $context.State = $mockState
            $context.RepoManager = $mockRepoManager
            
            # Comando a testear
            $command = [NavigationCommand]::new()
        }
        
        It "Debe navegar correctamente" {
            # Arrange
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_DOWN }
            
            # Act
            $result = $command.Execute($keyPress, $context)
            
            # Assert
            $result | Should -Be $true
        }
    }
}
```

## Creación de Nuevos Mocks

Si necesitas crear un mock nuevo (no está en MockCommonServices.ps1):

### Paso 1: Verificar que existe la interfaz

```powershell
# Buscar en src/Core/Interfaces/
Get-ChildItem "src\Core\Interfaces" -Filter "I*.ps1"
```

Si no existe, **primero crea la interfaz** siguiendo el patrón:

```powershell
# src/Core/Interfaces/IMiServicio.ps1
class IMiServicio {
    [string] MiMetodo([string]$param) {
        throw "Not Implemented: MiMetodo must be overridden"
    }
}
```

### Paso 2: Crear el mock

```powershell
class MockMiServicio : IMiServicio {
    [string] MiMetodo([string]$param) {
        return "valor mockeado"
    }
}
```

### Paso 3: Agregarlo a MockCommonServices.ps1 si es reutilizable

```powershell
# En tests/Mocks/MockCommonServices.ps1
$global:MockServiceDefinitions = @'
# ... mocks existentes ...

# ═════════════════════════════════════════════════════════════════════════════
# MOCK MI SERVICIO
# ═════════════════════════════════════════════════════════════════════════════
class MockMiServicio : IMiServicio {
    [string] MiMetodo([string]$param) { return "mock" }
}

'@
```

## Troubleshooting

### Error: "Cannot convert PSCustomObject to IMyInterface"

**Causa:** Intentaste asignar un PSCustomObject a una propiedad tipada con interfaz.

**Solución:** Crea una clase Mock que herede de la interfaz:

```powershell
# ❌ Esto causa el error:
$mock = [PSCustomObject]@{}
$context.Console = $mock

# ✅ Esto funciona:
class MockConsole : IConsoleHelper { ... }
$mock = New-Object MockConsole
$context.Console = $mock
```

### Error: "Type 'MockX' already exists"

**Causa:** Estás redefiniendo una clase Mock que ya existe en la sesión.

**Solución:** Usa `Invoke-Expression` solo en `BeforeAll`, nunca en `BeforeEach`.

### Error: "Method 'X' not found on Mock"

**Causa:** Tu mock no implementa todos los métodos de la interfaz.

**Solución:** Copia TODOS los métodos de la interfaz al mock, aunque devuelvan valores vacíos.

## Recursos

- [Estrategia de Testing](../technical_decisions/001-powershell-testing-strategy.md)
- [Reporte de Interfaces](./interface_implementation_report.md)
- [SOLID Refactoring Report](./solid_refactoring_report.md)

---

**Recuerda:** Cada vez que crees una nueva clase, crea primero su interfaz. Los tests deben depender de la interfaz, nunca de la clase concreta.
