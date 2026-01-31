# Tarea: Mejorar Cobertura de Tests al 80% - Proyecto repo-nav

## Contexto del Proyecto

Este es **repo-nav**, un navegador interactivo de repositorios Git escrito en **PowerShell 5.1** con arquitectura SOLID profesional.

### Principios Arquitectónicos (NO NEGOCIABLES)

1. **SOLID al 100%**: Dependency Inversion, Interface Segregation, Single Responsibility
2. **Interfaces para TODO**: Cada clase de servicio tiene su interfaz (prefijo `I`)
3. **Dependency Injection**: Vía `ServiceRegistry` global, NO instancias directas
4. **Mocks centralizados**: En `tests/Mocks/` siguiendo patrón establecido
5. **Test-Setup.ps1**: Carga el entorno completo en orden correcto (11 capas)
6. **Pester 5.7.1**: Framework de testing con cobertura JaCoCo

### Estructura de Capas (Orden de carga)

```
Layer 1: Config (ColorPalette, Constants)
Layer 2: Models (RepositoryModel, GitStatusModel, AliasInfo, etc.)
Layer 3: Core Interfaces (INavigationState, IGitService, etc.)
Layer 4: Services (AliasManager, GitService, SearchService, etc.)
Layer 5: UI (UIRenderer, Components, Views)
Layer 6: Core Managers (RepositoryManager)
Layer 7: UI Controllers & Views
Layer 8: Command System (NavigationCommand, GitCommand, etc.)
Layer 9: Flows (IntegrationFlowController, QuickChangeFlowController)
Layer 10: Engine (NavigationLoop, InputHandler, CommandFactory)
Layer 11: Startup (ServiceRegistry)
```

**CRÍTICO**: Respetar dependencias. Nunca una capa inferior puede depender de una superior.

### Herramientas Disponibles

```bash
# Ver cobertura actual de TODOS los archivos
npm run coverage

# Ver cobertura de UN archivo específico con líneas sin cubrir
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\Services\GitService.ps1" -ShowUncovered

# Ejecutar todos los tests con cobertura
npm run test:coverage

# Verificar proyecto completo (incluye pre-push hook)
npm run verify
```

## Archivos a Trabajar (Prioridad Alta)

Llevar estos archivos de su cobertura actual al **80% mínimo**:

```
[!!] 11.36% | Core/Services/OnboardingService.ps1
[!!] 12.06% | Core/RepositoryManager.ps1
[!!] 12.87% | Core/State/NavigationState.ps1
[!!] 15.79% | UI/Components/ColorSelector.ps1
[!!] 16.67% | Core/Interfaces/IConsoleHelper.ps1
[!!] 22.22% | Services/WindowSizeCalculator.ps1
[!!] 33.33% | Core/Commands/ExitCommand.ps1
[!!] 34.78% | Config/Constants.ps1
[!!] 35.00% | Core/Common/OperationResult.ps1
[!!] 42.86% | Core/Commands/NpmCommand.ps1
[!!] 44.49% | Services/GitService.ps1
[!!] 50.00% | Models/AliasInfo.ps1
[!!] 50.00% | Services/ConsoleProgressReporter.ps1
[!!] 56.52% | Services/ConfigurationService.ps1
[ -] 64.29% | Services/GitReadService.ps1
[ -] 67.44% | Services/HiddenReposService.ps1
[ -] 72.73% | Core/Services/GitStatusManager.ps1
[ -] 75.00% | Startup/ServiceRegistry.ps1
[ -] 77.50% | Models/RepositoryModel.ps1
[ -] 79.17% | Core/Commands/ToggleHiddenVisibilityCommand.ps1
```

## Proceso de Trabajo (OBLIGATORIO)

### 1. Analizar ANTES de escribir tests

```bash
# Ver el archivo y su cobertura actual
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\path\to\file.ps1" -ShowUncovered
```

Esto te dice **exactamente qué líneas faltan**.

### 2. Entender el archivo

- Lee el código fuente completo
- Identifica dependencias (qué servicios usa)
- Verifica si ya existe un archivo de test (buscar en `tests/Pester/Unit/`)
- Si existe test, EXTENDER. NO reescribir.

### 3. Crear/Extender Tests

#### Patrón de Test Correcto

```powershell
BeforeAll {
    # Cargar entorno completo
    . "$PSScriptRoot\..\..\Test-Setup.ps1"
    
    # Cargar mocks necesarios
    . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
    # ... otros mocks si se necesitan
}

Describe "NombreClase" {
    BeforeEach {
        # Setup para cada test
        $mockService = [MockService]::new()
        # Registrar en ServiceRegistry si es necesario
    }
    
    Context "Método o Funcionalidad" {
        It "Debe hacer X cuando Y" {
            # Arrange
            $sut = [ClaseReal]::new($mockService)
            
            # Act
            $result = $sut.Metodo($param)
            
            # Assert
            $result | Should -Be $esperado
        }
    }
    
    AfterEach {
        # Cleanup si es necesario
    }
}
```

#### Crear Mocks (si no existen)

**Ubicación**: `tests/Mocks/Mock{NombreServicio}.ps1`

```powershell
# Cargar interfaz
. "$PSScriptRoot\..\..\src\Core\Interfaces\IServicio.ps1"

class MockServicio : IServicio {
    # Propiedades para tracking
    [int]$MetodoLlamado = 0
    [object]$UltimoParametro = $null
    
    # Implementar TODOS los métodos de la interfaz
    [string] Metodo([string]$param) {
        $this.MetodoLlamado++
        $this.UltimoParametro = $param
        return "mock-result"
    }
}
```

### 4. Ejecutar y Verificar

```bash
# Test del archivo específico
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\path\to\file.ps1"

# Ver si llegaste al 80%
# Si no, ejecutar con -ShowUncovered para ver qué falta
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\path\to\file.ps1" -ShowUncovered
```

### 5. Validar TODO el proyecto

```bash
# Asegurar que no rompiste nada
npm run test:coverage

# Ver cobertura global
npm run coverage
```

## Reglas de Oro (NO ROMPER)

### ✅ HACER

1. **Tests unitarios puros**: Mock TODAS las dependencias externas
2. **Seguir AAA**: Arrange, Act, Assert
3. **Nombres descriptivos**: "Should return empty array when no repositories found"
4. **Un concepto por test**: No probar múltiples cosas en un `It`
5. **Usar mocks del proyecto**: Reutilizar `MockCommonServices.ps1`, `MockRepositoryManager.ps1`, etc.
6. **Testear edge cases**: null, empty, errores, etc.
7. **BeforeEach para setup**: Cada test debe ser independiente
8. **Leer tests existentes**: Ver `ArrayHelper.Tests.ps1`, `AliasManager.Tests.ps1` como ejemplos

### ❌ NO HACER

1. **NO instanciar servicios reales**: Siempre mocks
2. **NO llamar a Git real**: Mock GitService
3. **NO acceder al file system**: Mock ConfigurationService
4. **NO usar `Invoke-Expression`**: Cargar con dot-sourcing (`. $path`)
5. **NO hardcodear rutas**: Usar `$PSScriptRoot` y paths relativos
6. **NO testear implementaciones privadas**: Solo API pública
7. **NO duplicar tests**: Si ya existe, extender
8. **NO tests que dependen de orden**: Cada test independiente
9. **NO guarradas de peruano**: Código limpio, profesional, mantenible

## Ejemplo Completo: GitService

```powershell
# tests/Pester/Unit/GitService.Tests.ps1

BeforeAll {
    . "$PSScriptRoot\..\..\Test-Setup.ps1"
}

Describe "GitService" {
    BeforeEach {
        $sut = [GitService]::new()
    }
    
    Context "IsGitRepository" {
        It "Should return true when .git folder exists" {
            # Arrange
            $testPath = "TestDrive:\repo"
            New-Item -Path $testPath -ItemType Directory -Force
            New-Item -Path "$testPath\.git" -ItemType Directory -Force
            
            # Act
            $result = $sut.IsGitRepository($testPath)
            
            # Assert
            $result | Should -BeTrue
        }
        
        It "Should return false when .git folder does not exist" {
            # Arrange
            $testPath = "TestDrive:\notrepo"
            New-Item -Path $testPath -ItemType Directory -Force
            
            # Act
            $result = $sut.IsGitRepository($testPath)
            
            # Assert
            $result | Should -BeFalse
        }
        
        It "Should return false for null path" {
            # Act
            $result = $sut.IsGitRepository($null)
            
            # Assert
            $result | Should -BeFalse
        }
    }
}
```

## Workflow Sugerido

```bash
# 1. Ver qué archivos necesitan trabajo
npm run coverage

# 2. Elegir UN archivo (empezar por los más fáciles: 50-79%)
# 3. Ver líneas sin cubrir
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\Services\HiddenReposService.ps1" -ShowUncovered

# 4. Añadir tests para esas líneas
# 5. Verificar progreso
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\Services\HiddenReposService.ps1"

# 6. Repetir hasta 80%
# 7. Siguiente archivo

# 8. Al final, validar todo
npm run coverage:full
```

## Objetivo Final

- Cobertura global del proyecto: **80%+**
- Cada archivo en la lista: **80%+**
- TODOS los tests pasando
- Código limpio y mantenible
- Pre-push hook debe pasar

## Archivos de Referencia (Ejemplos Perfectos)

- `tests/Pester/Unit/ArrayHelper.Tests.ps1` - 100% coverage ✓
- `tests/Pester/Unit/AliasManager.Tests.ps1` - 80%+ coverage ✓
- `tests/Mocks/MockCommonServices.ps1` - Patrón de mocks ✓

**IMPORTANTE**: Este proyecto está bien arquitecturado. Tu trabajo es mantener ese estándar y mejorarlo, no degradarlo. Tests de calidad, código limpio, respeto por la arquitectura existente.

¿Entendido? Empecemos. 🚀
