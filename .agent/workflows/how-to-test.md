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

### B. Mock Incompleto - ¡EL ERROR MÁS COMÚN! 🚨
**Síntoma:** Tests fallan con errores como:
- `"Method invocation failed because [MockConsoleHelper] does not contain a method named 'ClearCurrentLine'"`
- `"A parameter cannot be found that matches parameter name 'default'"`
- `"Cannot find an overload for 'MethodName' and the argument count: 'X'"`

**Causa:** El mock no implementa TODOS los métodos/sobrecargas que la interfaz real tiene.

**Ejemplo del Problema:**
```powershell
# Interfaz real tiene 2 sobrecargas
interface IConsoleHelper {
    [bool] ConfirmAction([string]$prompt)
    [bool] ConfirmAction([string]$prompt, [bool]$default)  # ← Faltaba en el mock!
}

# Mock solo tenía 1
class MockConsoleHelper : IConsoleHelper {
    [bool] ConfirmAction([string]$prompt) { return $true }
    # Falta la sobrecarga con 2 parámetros
}
```

**Cómo Detectarlo:**
1. **Leer el error:** PowerShell te dirá qué método/parámetro falta
2. **Buscar la interfaz real:** Encuentra `IConsoleHelper.ps1` o similar
3. **Comparar:** Verifica que el mock tenga TODOS los métodos y sobrecargas

**Solución - Checklist de Verificación de Mocks:**
```powershell
# 1. Abrir la interfaz real
# Ejemplo: src/Core/Interfaces/IConsoleHelper.ps1

# 2. Listar TODOS los métodos y sobrecargas
interface IConsoleHelper {
    [void] ClearForWorkflow()
    [bool] ConfirmAction([string]$prompt)
    [bool] ConfirmAction([string]$prompt, [bool]$default)  # ← SOBRECARGA
    [void] ClearCurrentLine()
    [int] GetWindowWidth()
    # ... etc
}

# 3. Verificar que el mock los tiene TODOS
class MockConsoleHelper : IConsoleHelper {
    [void] ClearForWorkflow() {}
    [bool] ConfirmAction([string]$prompt) { return $true }
    [bool] ConfirmAction([string]$prompt, [bool]$default) { return $true }  # ✅ Añadido
    [void] ClearCurrentLine() {}  # ✅ Añadido
    [int] GetWindowWidth() { return 120 }
    # ... etc - TODOS implementados
}
```

**Mejores Prácticas para Prevenir Esto:**
1. **Cuando añades un método a una interfaz, actualiza TODOS los mocks inmediatamente**
2. **Documenta las sobrecargas claramente:**
   ```powershell
   # Mock debe tener ambas sobrecargas de ConfirmAction
   [bool] ConfirmAction([string]$prompt) { return $true }
   [bool] ConfirmAction([string]$prompt, [bool]$default) { return $true }
   ```
3. **Usa comentarios en mocks para trackear versión:**
   ```powershell
   # MockConsoleHelper - v2.0 - Updated: 2026-02-01
   # Implements: IConsoleHelper (all methods + overloads)
   class MockConsoleHelper : IConsoleHelper { ... }
   ```
4. **Test de "Smoke" para mocks:**
   ```powershell
   It "Mock implements all interface methods" {
       $mock = [MockConsoleHelper]::new()
       # Verifica que existan los métodos críticos
       $mock.PSObject.Methods.Name -contains 'ClearCurrentLine' | Should -Be $true
       # O intenta llamarlos con diferentes sobrecargas
       { $mock.ConfirmAction("test") } | Should -Not -Throw
       { $mock.ConfirmAction("test", $true) } | Should -Not -Throw
   }
   ```

**Caso Real - Lección Aprendida (Enero 2026):**
Durante los tests de `NpmCommand`, encontramos que `MockConsoleHelper` le faltaban:
- ✅ Sobrecarga: `ConfirmAction([string]$prompt, [bool]$default)`
- ✅ Método: `ClearCurrentLine()`

**Impacto:** Tests fallaban con "Cannot find overload" aunque el código de producción era correcto.

**Solución aplicada:**
```powershell
# tests/Mocks/MockCommonServices.ps1
class MockConsoleHelper : IConsoleHelper {
    # ... métodos existentes ...
    [bool] ConfirmAction([string]$prompt) { return $true }
    [bool] ConfirmAction([string]$prompt, [bool]$default) { return $true }  # ← AÑADIDO
    [void] ClearCurrentLine() {}  # ← AÑADIDO
    # ...
}
```

**Regla de Oro:** Si añades/modificas una interfaz, ejecuta TODOS los tests. Los mocks incompletos se revelarán inmediatamente.

### C. Mocks de Git se sobrescriben
**Causa:** Pester mocks son específicos de alcance.
**Solución:** Usa `-ParameterFilter` para diferenciar llamadas a `git`:
```powershell
Mock GitMockStub { return "A" } -ParameterFilter { $Arguments -contains "status" }
Mock GitMockStub { return "B" } -ParameterFilter { $Arguments -contains "branch" }
```

### D. `$PSScriptRoot` vacío
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

| Mock | Interfaz | Uso | Última Actualización |
|------|----------|-----|---------------------|
| `MockRepositoryManager` | `IRepositoryManager` | Gestión de repositorios | 2026-01 |
| `MockGitService` | `IGitService` | Operaciones de Git de alto nivel | 2026-01 |
| `MockConsoleHelper` | `IConsoleHelper` | Escribir en consola/host | 2026-02 ✅ |
| `MockUIRenderer` | `IUIRenderer` | Renderizado visual | 2026-01 |
| `MockUserPreferencesService` | `IUserPreferencesService` | Configuración de usuario | 2026-01 |
| `MockNpmService` | `INpmService` | Operaciones npm | 2026-01 |
| `MockJobService` | `IJobService` | Gestión de background jobs | 2026-02 ✅ |

**⚠️ A🔍 Checklist Pre-Test (OBLIGATORIO)

Antes de escribir o ejecutar tests, verifica:

- [ ] **¿El mock está actualizado?** Compara con la interfaz real
- [ ] **¿Hay sobrecargas de métodos?** Implementa TODAS
- [ ] **¿Tests previos pasan?** No rompas lo que funciona
- [ ] **¿Usas mocks de comandos nativos (git, npm)?** Configura el patrón `Stub + Alias`
- [ ] **¿El error menciona "cannot find method/overload"?** → Mock incompleto (Sección 4.B)
## 6.1 🚫 Archivos Excluidos de Cobertura

Ciertos archivos NO necesitan tests porque no contienen lógica ejecutable:

### Automáticamente Excluidos (ver `PesterConfig.json`)
```json
"ExcludeTests": [
    "**/*/_index.ps1",           // Archivos de carga/bootstrapping
    "**/Interfaces/*.ps1",       // Definiciones de interfaces
    "**/Resources/**/*.ps1",     // Recursos (i18n, etc.)
    "**/Dev/*.ps1"               // Herramientas de desarrollo
]
```

### ¿Por qué se excluyen?

**1. Interfaces (`src/Core/Interfaces/*.ps1`)**
- Son solo definiciones de contratos (métodos abstractos)
- No contienen lógica ejecutable
- Se validan indirectamente al testear las implementaciones

Ejemplo:
```powershell
# src/Core/Interfaces/IOptionSelector.ps1
class IOptionSelector : ConsoleView {
    [object] Show([SelectionOptions]$config) { return $null }  # Solo definición
}
```
✅ **No necesita tests** - Se testea via implementaciones reales y mocks.

**2. Archivos `_index.ps1`**
- Solo cargan/importan otros archivos
- No contienen lógica de negocio
- Son bootstrapping puro

Ejemplo:
```powershell
# src/Services/_index.ps1
. "$PSScriptRoot/AliasManager.ps1"
. "$PSScriptRoot/ConfigurationService.ps1"
# ... solo importaciones
```
✅ **No necesita tests** - Se valida al cargar el proyecto completo.

**3. Resources (`src/Resources/**`)**
- Archivos de datos (i18n, configuración)
- No contienen código ejecutable
- Son datos estáticos

**4. Dev Tools (`src/Dev/*.ps1`)**
- Herramientas de desarrollo temporal
- No forman parte del código de producción

### ⚠️ Si necesitas añadir más exclusiones

Edita `PesterConfig.json`:
```json
"ExcludeTests": [
    "**/*/_index.ps1",
    "**/Interfaces/*.ps1",
    "**/TuNuevoPatron/*.ps1"  // Añade aquí
]
```

**Criterio para excluir:**
- ✅ No tiene lógica ejecutable
- ✅ No tiene decisiones (if/switch/loops)
- ✅ No tiene cálculos ni transformaciones
- ❌ Si tiene cualquiera de lo anterior → SÍ necesita tests
## 7. Próximos Pasos para IAs

1.  **Leer `HANDOFF_COVERAGE.md`**: Para ver qué archivos faltan.
2.  **Verificar cobertura**: Ejecuta `.\scripts\Test-FileCoverage.ps1 -SourceFile "<archivo>"`.
3.  **Seguir el patrón existente**: Copia el estilo de `GitReadService.Tests.ps1` para cosas de bajo nivel o `Commands.Tests.ps1` para comandos.
4.  **Validar mocks antes de usarlos**: Compara con la interfaz real (Sección 4.B).
5.  **Documentar cambios en mocks**: Añade comentario con fecha si actualizas un mock.

**Objetivo: 80% Code Coverage global. Sin excepciones.**

---

## 📖 Aprendizajes de Casos Reales

### Caso 1: Mock Incompleto en NpmCommand (Feb 2026)
**Problema:** `MockConsoleHelper` no implementaba todos los métodos de `IConsoleHelper`.  
**Síntoma:** `"A parameter cannot be found that matches parameter name 'default'"`  
**Causa:** Faltaban sobrecargas y métodos nuevos añadidos a la interfaz.  
**Solución:** Actualizar el mock con todas las firmas:
```powershell
[bool] ConfirmAction([string]$prompt, [bool]$default) { return $true }
[void] ClearCurrentLine() {}
```
**Lección:** Siempre verifica que el mock implemente TODA la interfaz, incluyendo sobrecargas.

### Caso 2: Tests Fallando por Código Interno de Jobs (Feb 2026)
**Problema:** Tests intentaban verificar `LastScript` en un mock de `JobService`.  
**Síntoma:** `"Cannot index into a null array"` al intentar acceder a `$mockJob.LastScript`.  
**Causa:** El scriptblock pasado a un job no es capturables en el mock porque se ejecuta en otro contexto.  
**Solución:** No intentar verificar el contenido interno de scriptblocks. En su lugar:
```powershell
# ❌ MAL: Intentar capturar scriptblock interno
$script:mockJob.LastScript | Should -Not -BeNullOrEmpty

# ✅ BIEN: Verificar comportamiento observable
{ $script:command.Execute($key, $context) } | Should -Not -Throw
# Y/o verificar efectos secundarios (archivos borrados, estado cambiado, etc.)
```
**Lección:** Mock comportamiento observable, no implementación interna.
## 6. Próximos Pasos para IAs

1.  **Leer `HANDOFF_COVERAGE.md`**: Para ver qué archivos faltan.
2.  **Verificar cobertura**: `npm run test:coverage`.
3.  **Seguir el patrón existente**: Copia el estilo de `GitReadService.Tests.ps1` para cosas de bajo nivel o `Commands.Tests.ps1` para comandos.

**Objetivo: 80% Code Coverage global. Sin excepciones.**
