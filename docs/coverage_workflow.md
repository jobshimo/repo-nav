# Workflow para Subir Cobertura al 80%

**Fecha:** 31 de Enero de 2026  
**Objetivo:** Llevar cada archivo a 80% de cobertura de forma incremental y enfocada

## Problema que Resolvemos

❌ **Antes:**
- Las AI saltan de archivo en archivo sin terminar ninguno
- Difícil saber qué archivos necesitan más trabajo
- No hay forma de medir progreso archivo por archivo

✅ **Ahora:**
- Sistema enfocado: un archivo a la vez
- Scripts para medir cobertura individual
- Priorización clara de qué archivos trabajar

## Scripts Disponibles

### 1. `List-CoverageStatus.ps1` - Vista General

**Propósito:** Ver qué archivos necesitan trabajo

```powershell
# Ver todos los archivos bajo 80%
.\scripts\List-CoverageStatus.ps1

# Ver archivos bajo 60%
.\scripts\List-CoverageStatus.ps1 -MinCoverage 60

# Ordenar por prioridad (Services primero)
.\scripts\List-CoverageStatus.ps1 -SortBy Priority
```

**Output:**
```
Status  Coverage    Lines        File                        Path
------  --------    -----        ----                        ----
✗       45.2%       23/51        NpmService.ps1              src/Services/NpmService.ps1
○       67.8%       45/66        GitService.ps1              src/Services/GitService.ps1
✓       82.1%       78/95        AliasManager.ps1            src/Services/AliasManager.ps1
```

### 2. `Test-FileCoverage.ps1` - Test Enfocado

**Propósito:** Medir y mejorar UN archivo específico

```powershell
# Test básico de un archivo
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1"

# Ver qué líneas faltan cubrir
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1" -ShowUncovered

# Especificar archivo de test manualmente
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Core/RepositoryManager.ps1" -TestFile "tests/Pester/Unit/RepositoryManager.Tests.ps1"
```

**Output:**
```
═══════════════════════════════════════════════════════════════
 CODE COVERAGE REPORT: NpmService.ps1
═══════════════════════════════════════════════════════════════

 Commands Covered:  34 / 75
 Coverage:          45.3% (need +34.7% to reach 80%)

 Progress: [██████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░]

───────────────────────────────────────────────────────────────
 UNCOVERED LINES (need tests for these):
───────────────────────────────────────────────────────────────

 Line   24: if ($proc.ExitCode -ne 0) {
 Line   25:     Write-Error "rmdir failed"
 Line   37: $size = (Get-ChildItem -Path $nodeModulesPath -Recurse)
 ...
```

## Workflow Recomendado

### Paso 1: Identificar Prioridades

```powershell
# Ver estado actual
.\scripts\List-CoverageStatus.ps1 -SortBy Priority
```

**Prioridad de archivos:**
1. **Services** (críticos para funcionalidad)
2. **Core** (lógica central)
3. **UI** (menos crítico, más difícil de testear)
4. **Models** (usualmente ya cubiertos)

### Paso 2: Seleccionar un Archivo

Elige el archivo con **menor cobertura** en la categoría de **mayor prioridad**.

Ejemplo: Si `NpmService.ps1` tiene 45% y es un Service, empieza por ahí.

### Paso 3: Medir Estado Actual

```powershell
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1" -ShowUncovered
```

Esto te muestra:
- ✅ Qué % tiene ahora
- ❌ Qué líneas faltan cubrir
- 📊 Cuánto falta para 80%

### Paso 4: Escribir Tests

Abre el archivo de test (si no existe, créalo):

```powershell
# Estructura esperada
tests/Pester/Unit/Services/NpmService.Tests.ps1
```

**Enfoque:**
- ❌ No intentes cubrir TODO de una vez
- ✅ Cubre grupos lógicos de métodos
- ✅ Escribe 2-3 tests, re-mide, repite

### Paso 5: Re-medir Progreso

Después de agregar tests:

```powershell
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1"
```

Si mejoraste:
- ✅ Commit los cambios
- ✅ Continúa con más tests del mismo archivo

Si llegaste a 80%:
- ✅ Commit con mensaje: "test: NpmService coverage 80%+"
- ✅ Pasa al siguiente archivo

### Paso 6: Repetir

Vuelve al Paso 1 y elige el siguiente archivo.

## Estructura de Tests

### Template para Nuevo Test

```powershell
Describe "NombreDelArchivo Tests" {
    BeforeAll {
        # Cargar entorno
        . "$PSScriptRoot\..\..\..\tests\Test-Setup.ps1" | Out-Null
        
        # Cargar mocks
        . "$PSScriptRoot\..\..\Mocks\MockCommonServices.ps1"
        . "$PSScriptRoot\..\..\Mocks\MockRepositoryManager.ps1"
    }
    
    Context "Método1" {
        BeforeEach {
            # Setup específico
            $service = [MyService]::new()
        }
        
        It "Debe hacer X cuando Y" {
            # Arrange
            $input = "test"
            
            # Act
            $result = $service.Method1($input)
            
            # Assert
            $result | Should -Be "expected"
        }
    }
}
```

## Estrategia por Tipo de Archivo

### Services
- Testear cada método público
- Mockear dependencias externas (filesystem, git, npm)
- Cubrir casos de error

### Core/Managers
- Testear flujos completos
- Mockear servicios inyectados
- Verificar interacciones entre componentes

### UI/Components
- Testear lógica de negocio (no rendering)
- Mockear Console/Terminal
- Verificar output esperado

## Tips para Mejorar Cobertura Rápido

### 1. Identifica Ramas No Cubiertas

```powershell
# El flag -ShowUncovered te muestra exactamente qué líneas faltan
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/MyService.ps1" -ShowUncovered
```

### 2. Prioriza Error Paths

Las líneas no cubiertas suelen ser:
- ❌ Validaciones (if $null, if empty)
- ❌ Error handling (catch blocks)
- ❌ Edge cases

Escribe tests específicos para estos casos:

```powershell
It "Debe lanzar error si parámetro es null" {
    { $service.Method($null) } | Should -Throw
}

It "Debe retornar false si archivo no existe" {
    Mock Test-Path { return $false }
    $result = $service.HasFile("fake.txt")
    $result | Should -Be $false
}
```

### 3. Usa Mocks para Casos Difíciles

No necesitas filesystem real ni git real:

```powershell
Mock Test-Path { return $true }
Mock Get-ChildItem { return @() }
Mock git { return "main" }
```

### 4. No Testees Código Muerto

Si encuentras código que nunca se ejecuta:
- ❌ No pierdas tiempo escribiendo tests
- ✅ Elimina el código muerto
- ✅ O documenta por qué existe

## Métricas de Éxito

### Por Archivo
- 🎯 **Target:** 80% coverage
- ✅ **Bueno:** 70-79%
- ⚠️ **Mejora Necesaria:** 60-69%
- ❌ **Crítico:** <60%

### Por Sesión de Trabajo
**Objetivo realista:** 2-3 archivos al 80% por sesión

### Global
**Meta final:** 80% de cobertura total del proyecto

## Ejemplo Completo: Mejorando NpmService

```powershell
# 1. Ver estado
PS> .\scripts\List-CoverageStatus.ps1 -SortBy Priority
# Output: NpmService.ps1 - 45% ❌

# 2. Medir en detalle
PS> .\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1" -ShowUncovered
# Output: Falta cubrir: RemoveNodeModules, GetNodeModulesSize, error paths

# 3. Agregar tests a tests/Pester/Unit/Services/NpmService.Tests.ps1
# (escribir 5-6 tests para métodos faltantes)

# 4. Re-medir
PS> .\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1"
# Output: 73% ○ (mejora!)

# 5. Agregar más tests para casos de error

# 6. Re-medir
PS> .\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/NpmService.ps1"
# Output: 82% ✓ TARGET MET!

# 7. Commit
PS> git add tests/Pester/Unit/Services/NpmService.Tests.ps1
PS> git commit -m "test: NpmService coverage 82% (80%+ target met)"

# 8. Siguiente archivo
PS> .\scripts\List-CoverageStatus.ps1 -SortBy Priority
# Elegir el siguiente...
```

## Preguntas Frecuentes

**Q: ¿Qué hago si no existe el test file?**  
A: Créalo siguiendo el template. El script te sugiere la ubicación.

**Q: ¿Puedo trabajar en múltiples archivos a la vez?**  
A: NO. Ese es el problema que estamos evitando. Enfócate en uno hasta llegar a 80%.

**Q: ¿Qué pasa si un archivo es muy grande?**  
A: Considera refactorizar el archivo en clases más pequeñas (SOLID - SRP).

**Q: ¿80% es suficiente?**  
A: Sí. 100% es raramente necesario y consume mucho tiempo. 80% es el sweet spot.

**Q: ¿Y si hay código difícil de testear?**  
A: Refactoriza para inyección de dependencias. Usa interfaces y mocks.

## Comandos Rápidos

```powershell
# Ver estado general
.\scripts\List-CoverageStatus.ps1

# Trabajar en un archivo
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/MyService.ps1" -ShowUncovered

# Verificar mejora
.\scripts\Test-FileCoverage.ps1 -SourceFile "src/Services/MyService.ps1"

# Test completo del proyecto
.\scripts\Test-WithCoverage.ps1
```

---

**Recuerda:** Un archivo al 80% es mejor que 10 archivos al 30%. Enfoque incremental.
