# 🧪 Guía Maestra de Testing en Repo-Nav

**Versión:** 2.0 (Enero 2026)
**Filosofía:** SOLID + Clean Code + Dependency Injection

Esta guía establece el estándar **OBLIGATORIO** para escribir tests en este repositorio. Cualquier PR que no siga estos principios será rechazado.

---

## 1. 🧠 La Filosofía: ¿Por qué Mockear?

En `repo-nav` seguimos estrictamente el principio de **Inversión de Dependencias (D en SOLID)**.

### El Problema
El código "tradicional" de PowerShell suele estar fuertemente acoplado:
```powershell
# ❌ MAL: Acoplamiento fuerte
function Get-RepoStatus {
    $git = New-Object GitService # Dependencia directa
    return $git.GetStatus()
}
```
Si quieres testear `Get-RepoStatus`, ¡estás obligado a ejecutar `GitService` real! Esto hace los tests lentos, frágiles y dependientes del sistema de archivos.

### La Solución: Interfaces y Mocks
En su lugar, dependemos de **abstracciones** (Interfaces):

```powershell
# ✅ BIEN: Inyección de Dependencias
class RepoManager {
    [IGitService] $GitService

    RepoManager([IGitService] $git) { # Inyectamos la interfaz
        $this.GitService = $git
    }

    [string] GetStatus() {
        return $this.GitService.GetStatus()
    }
}
```

Ahora, en los tests, podemos inyectar un **Mock** (una clase falsa que controlamos 100%):
```powershell
$mockGit = [MockGitService]::new() # Cumple con IGitService
$manager = [RepoManager]::new($mockGit)
```

**Beneficios:**
1.  **Velocidad**: No tocamos disco ni red.
2.  **Determinismo**: Controlamos exactamente qué devuelve el mock (éxito, error, null).
3.  **Seguridad**: No borramos archivos reales por error.

---

## 2. 🛠️ Estrategia de Mocks en PowerShell 5.1

PowerShell 5.1 no tiene `interface` nativa, así que usamos el patrón de **Clases Abstractas Simuladas**.

### Regla de Oro #1: NUNCA usar `Add-Member` en objetos reales
No intentes "parchear" objetos vivos. Es frágil y sucio.

❌ **Mal:** ` $obj | Add-Member -Name "Method" -Value { ... } -Force `
✅ **Bien:** Crear una clase `class MockX : IX { ... }`

### Regla de Oro #2: Mockear Comandos Nativos (Git, Node)
Pester no puede mockear `git.exe` directamente si se llama como comando nativo. Usamos el patrón **Alias-Stub**.

#### Patrón `GitMockStub` (OBLIGATORIO para tests de Git)
Si tu servicio llama a `git` (o cualquier ejecutable), debes configurar el test así:

```powershell
Describe "GitService" {
    BeforeAll {
        # 1. Definir función stub
        function global:GitMockStub { param([Parameter(ValueFromRemainingArguments=$true)]$Arguments) }
        
        # 2. Crear Alias git -> GitMockStub (Precedencia sobre git.exe)
        if (-not (Get-Command git -CommandType Alias -ErrorAction SilentlyContinue)) {
            Set-Alias -Name git -Value GitMockStub -Scope Global -Option AllScope
        }
    }

    BeforeEach {
        # 3. Mockear la función stub, no el exe
        Mock GitMockStub { 
            $script:LASTEXITCODE = 0 # IMPORTANTE: Simular éxito
            return "branch-name" 
        } -ParameterFilter { $Arguments -contains "rev-parse" }
    }
}
```

---

## 3. 🏗️ Estructura de un Test (AAA)

Todos los tests deben seguir el patrón **Arrange, Act, Assert**.

```powershell
Describe "MyService" {
    BeforeAll {
        # Carga inteligente de dependencias
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        . "$scriptRoot\tests\Test-Setup.ps1" | Out-Null
        
        # Cargar mocks comunes
        . "$scriptRoot\tests\Mocks\MockCommonServices.ps1"
    }

    Context "MethodName behavior" {
        BeforeEach {
            # Arrange (Preparar)
            $mockGit = [MockGitService]::new()
            $service = [MyService]::new($mockGit)
        }

        It "Should return X when Y happens" {
             # Arrange (Configuración específica)
             $mockGit.SetReturnValue("status", "clean")

             # Act (Ejecutar)
             $result = $service.GetStatus()

             # Assert (Verificar)
             $result | Should -Be "clean"
        }
    }
}
```

---

## 4. ⚠️ Trampas Comunes y Soluciones

### A. "Cannot convert value... to type IX"
**Causa:** Estás pasando un `PSCustomObject` o una clase que no hereda explícitamente de la interfaz `IX`.
**Solución:**
Crea una clase mock real:
```powershell
class MockMyService : IMyService { ... }
```
Si necesitas flexibilidad rápida (menos recomendado pero posible para DTOs): castear con `[PSCustomObject]` no funciona para tipos estrictos. Usa la clase real con propiedades vacías.

### B. Mocks de Git se sobrescriben
**Causa:** Pester mocks son específicos de alcance.
**Solución:** Usa `-ParameterFilter` para diferenciar llamadas a `git`:
```powershell
Mock GitMockStub { return "A" } -ParameterFilter { $Arguments -contains "status" }
Mock GitMockStub { return "B" } -ParameterFilter { $Arguments -contains "branch" }
```

### C. `$PSScriptRoot` vacío
**Causa:** Pester a veces pierde el contexto del path.
**Solución:** Usa el snippet robusto de path resolution:
```powershell
$currentPath = $PSScriptRoot
if (-not $currentPath) { $currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Resolve-Path "$currentPath\..\..\.."
```

---

## 5. 📚 Catálogo de Mocks Disponibles
No reinventes la rueda. Mira en `tests/Mocks/`:

| Mock | Interfaz | Uso |
|------|----------|-----|
| `MockRepositoryManager` | `IRepositoryManager` | Gestión de repositorios |
| `MockGitService` | `IGitService` | Operaciones de Git de alto nivel |
| `MockConsoleHelper` | `IConsoleHelper` | Escribir en consola/host |
| `MockUIRenderer` | `IUIRenderer` | Renderizado visual |
| `MockUserPreferencesService` | `IUserPreferencesService` | Configuración de usuario |

---

## 6. Próximos Pasos para IAs

1.  **Leer `HANDOFF_COVERAGE.md`**: Para ver qué archivos faltan.
2.  **Verificar cobertura**: `npm run test:coverage`.
3.  **Seguir el patrón existente**: Copia el estilo de `GitReadService.Tests.ps1` para cosas de bajo nivel o `Commands.Tests.ps1` para comandos.

**Objetivo: 80% Code Coverage global. Sin excepciones.**
