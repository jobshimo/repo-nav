# 🔄 Handoff: Cobertura de Tests - repo-nav

## 📊 Progreso Actual (31 Enero 2026)

### ✅ Archivos Completados (4 archivos → 80%+)

| Archivo | Antes | Después | Tests Añadidos | Estado |
|---------|-------|---------|----------------|---------|
| **HiddenReposService.ps1** | 67.44% | **96.08%** | +13 | ✅ Completado |
| **GitReadService.ps1** | 64.29% | **92.98%** | +31 | ✅ Completado |
| **GitStatusManager.ps1** | 72.73% | **96.36%** | +10 | ✅ Completado |
| **RepositoryModel.ps1** | 77.50% | **100%** | +12 | ✅ Completado |
| **ToggleHiddenVisibilityCommand.ps1** | 79.17% | **96.43%** | +3 | ✅ Completado |

**Total: 69 tests nuevos añadidos**

---

## 🎯 Próximos Archivos Prioritarios

### Fáciles (Quick Wins - 1-2 tests cada uno):
1. **ServiceRegistry.ps1** - 75% → 80% (8 líneas, ya existe test)
2. **AliasInfo.ps1** - 50% → 80% (6 líneas totales)
3. **ConsoleProgressReporter.ps1** - 50% → 80% (4 líneas)

### Medianos (3-5 tests):
4. **ConfigurationService.ps1** - 56.52% → 80% (46 líneas)
5. **ExitCommand.ps1** - 33.33% → 80% (6 líneas)
6. **Constants.ps1** - 34.78% → 80% (23 líneas)
7. **OperationResult.ps1** - 35% → 80% (20 líneas)
8. **WindowSizeCalculator.ps1** - 22.22% → 80% (27 líneas)

### Complejos (10+ tests):
9. **GitService.ps1** - 45.76% → 80% (236 líneas) - Muchos métodos de Git
10. **NpmCommand.ps1** - 42.86% → 80% (175 líneas)

---

## 💡 Mi Experiencia - Valoración General

### ⭐ Dificultad: **6/10** (Moderada)

#### ✅ **Lo que funcionó bien:**

1. **Arquitectura SOLID del proyecto** - El proyecto está MUY bien estructurado
   - Interfaces claras (prefijo `I`)
   - Dependency Injection vía ServiceRegistry
   - Mocks centralizados en `tests/Mocks/`
   - Separación de concerns excelente

2. **Test-Setup.ps1** - Sistema de carga en capas perfecto
   - Carga automática de 11 capas en orden
   - No necesitas preocuparte por dependencias
   - Solo llamas `. "$projectRoot\tests\Test-Setup.ps1"`

3. **Ejemplos existentes** - Tests de referencia muy buenos:
   - `ArrayHelper.Tests.ps1` - 100% coverage
   - `AliasManager.Tests.ps1` - 80%+ coverage
   - Patrones consistentes y claros

4. **Mocks reutilizables** - No necesitas crear mocks desde cero:
   - `MockCommonServices.ps1`
   - `MockUserPreferencesService.ps1`
   - `MockRepositoryManager.ps1`
   - `MockParallelGitLoader.ps1`

#### 😓 **Desafíos encontrados:**

1. **Mocking de Git commands** (Dificultad: Alta)
   - PowerShell no permite mockear comandos nativos directamente
   - Solución: Crear alias `git` apuntando a función `GitMockStub` y mockear esa función
   - Los mocks se sobrescriben si no usas `$script:LASTEXITCODE = 0`
   - Ejemplo en `GitReadService.Tests.ps1` (líneas 20-30)

2. **Type casting estricto** (Dificultad: Media)
   - `CommandContext` espera objetos que implementen interfaces
   - NO puedes usar `[PSCustomObject]@{}` directamente
   - Debes usar las clases reales o crear clases mock que hereden de la interfaz
   - Ejemplo: Intenté mockear `HiddenReposService` con PSCustomObject → FALLÓ
   - Solución: Usar `[HiddenReposService]::new($null)` y añadir ScriptMethods con `Add-Member -Force`

3. **Test isolation** (Dificultad: Baja)
   - Algunos tests modifican estado global (ServiceRegistry)
   - Siempre usar `BeforeEach` para reset
   - Cuidado con mocks que persisten entre tests

4. **Paths en tests** (Dificultad: Baja pero molesta)
   - `$PSScriptRoot` a veces está vacío en Pester
   - Patrón correcto:
     ```powershell
     $scriptRoot = $PSScriptRoot
     if (-not $scriptRoot) {
         $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
     }
     $projectRoot = (Resolve-Path "$scriptRoot/../../../..").Path
     ```
   - Contar bien los niveles `..` según dónde esté el test

5. **Coverage reporting** (Dificultad: Baja)
   - El reporte global (`npm run coverage`) usa el XML generado por el último `test:coverage`
   - Para ver cambios individuales, ejecuta el test específico con `-CodeCoverage`
   - Luego ejecuta `npm run test:coverage` para actualizar el reporte global

#### 🚀 **Productividad:**

- Archivos simples (50-80%): **~10 minutos cada uno**
- Archivos medianos (30-50%): **~20-30 minutos cada uno**
- Archivos complejos (<30%): **~45-60 minutos cada uno**

**Estimación para llegar a 80% global:** 
- ~20 archivos más para completar
- ~6-8 horas de trabajo total
- **Factible en 1-2 sesiones de trabajo**

---

## 🎓 Lecciones Aprendidas / Best Practices

### 1. **Patrón AAA siempre**
```powershell
It "Should do X when Y" {
    # Arrange
    $service = [Service]::new($mockDep)
    
    # Act
    $result = $service.Method($param)
    
    # Assert
    $result | Should -Be $expected
}
```

### 2. **Edge cases obligatorios**
SIEMPRE testear:
- `null` inputs
- Empty strings / arrays
- Valores fuera de rango
- Errores esperados

### 3. **Mock Git commands correctamente**
```powershell
BeforeAll {
    if (-not (Get-Command git -CommandType Alias -ErrorAction SilentlyContinue)) {
        function global:GitMockStub { param([Parameter(ValueFromRemainingArguments=$true)]$Arguments) }
        Set-Alias -Name git -Value GitMockStub -Scope Global -Option AllScope
    }
}

BeforeEach {
    Mock GitMockStub { 
        $script:LASTEXITCODE = 0  # ← IMPORTANTE
        return "result" 
    } -ParameterFilter { $Arguments -contains "status" }
}
```

### 4. **No reescribir, EXTENDER**
Si existe test para el archivo:
1. ✅ Añade más tests al archivo existente
2. ❌ NO crees un nuevo archivo de test
3. ✅ Usa el mismo estilo y estructura

### 5. **Verificar cobertura específica**
```bash
# Ver líneas específicas sin cubrir
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\Services\Service.ps1" -ShowUncovered

# Ver cobertura de un archivo
Invoke-Pester -Path "tests\Pester\Unit\Service.Tests.ps1" `
              -CodeCoverage "src\Services\Service.ps1"
```

---

## 🔧 Comandos Útiles

```bash
# 1. Ver cobertura global
npm run coverage

# 2. Ver archivo específico con líneas faltantes
.\scripts\Test-FileCoverage.ps1 -SourceFile "src\path\to\file.ps1" -ShowUncovered

# 3. Ejecutar UN test específico
Invoke-Pester -Path "tests\Pester\Unit\MyTest.Tests.ps1"

# 4. Test con cobertura de UN archivo
Invoke-Pester -Path "tests\Pester\Unit\MyTest.Tests.ps1" `
              -CodeCoverage "src\path\to\file.ps1"

# 5. Ejecutar TODOS los tests con cobertura (actualiza reporte global)
npm run test:coverage

# 6. Validar proyecto completo (incluye pre-push hook)
npm run verify
```

---

## 📋 Workflow Recomendado

### Para cada archivo:

1. **Analizar** (2 min)
   ```bash
   .\scripts\Test-FileCoverage.ps1 -SourceFile "src\path\to\file.ps1" -ShowUncovered
   ```
   Esto te dice EXACTAMENTE qué líneas faltan.

2. **Leer código** (3 min)
   - Entender qué hace el archivo
   - Identificar dependencias
   - Ver si ya existe test (`tests/Pester/Unit/`)

3. **Escribir tests** (5-15 min)
   - Si existe test: Añadir casos faltantes
   - Si no existe: Crear nuevo archivo siguiendo patrón
   - Cubrir edge cases

4. **Verificar** (1 min)
   ```bash
   Invoke-Pester -Path "tests\..." -CodeCoverage "src\..."
   ```

5. **Iterar** hasta llegar a 80%+

6. **Commit** cuando el archivo llegue a 80%
   ```bash
   git add tests/...
   git commit -m "test: improve coverage for Service.ps1 (XX% → 80%+)"
   ```

---

## 🎯 Estrategia para continuar

### Orden sugerido (de más fácil a más difícil):

**Sesión 1: Quick Wins (30-45 min)**
1. ServiceRegistry (75% → 80%) - 1 test
2. AliasInfo (50% → 80%) - 2-3 tests
3. ConsoleProgressReporter (50% → 80%) - 2 tests
4. ExitCommand (33.33% → 80%) - 3 tests
5. Constants (34.78% → 80%) - 3-4 tests

**Sesión 2: Medianos (1-2 horas)**
6. OperationResult (35% → 80%)
7. WindowSizeCalculator (22.22% → 80%)
8. ColorSelector (15.79% → 80%)
9. ConfigurationService (56.52% → 80%)

**Sesión 3: Complejos (2-3 horas)**
10. GitService (45.76% → 80%) - Muchos métodos de Git
11. NpmCommand (42.86% → 80%) - Comandos npm
12. NavigationState (12.87% → 80%) - Estado complejo
13. RepositoryManager (12.06% → 80%) - Manager grande
14. OnboardingService (11.36% → 80%)

---

## ⚠️ Advertencias Importantes

### 🔴 NO HACER:
1. **NO instanciar servicios reales** sin mocks de dependencias
2. **NO llamar a Git real** - Mockear GitService siempre
3. **NO acceder al file system real** - Mock ConfigurationService
4. **NO usar `Invoke-Expression`** - Usar dot-sourcing (`. $path`)
5. **NO hardcodear rutas** - Usar `$PSScriptRoot` y paths relativos
6. **NO duplicar tests** - Extender archivos existentes
7. **NO tests que dependan de orden** - Cada test independiente

### 🟢 SIEMPRE HACER:
1. **Tests unitarios puros** - Mock TODAS las dependencias
2. **Seguir AAA** - Arrange, Act, Assert
3. **Nombres descriptivos** - "Should return X when Y"
4. **Un concepto por test** - No probar múltiples cosas
5. **BeforeEach para setup** - Tests independientes
6. **Testear edge cases** - null, empty, errores
7. **Verificar con archivo específico** antes de commit

---

## 📊 Métricas Actuales

- **Cobertura global**: ~16% → Objetivo: 80%
- **Archivos completados**: 5/20 prioritarios (25%)
- **Tests añadidos**: 69
- **Tests pasando**: 100% ✅
- **Tiempo invertido**: ~3 horas
- **Velocidad promedio**: ~23 tests/hora

---

## 🚀 Estado del Proyecto

### Calidad del Código Base: ⭐⭐⭐⭐⭐ (5/5)
- Arquitectura SOLID impecable
- Separación de concerns excelente
- Código limpio y bien documentado
- Patrones consistentes

### Facilidad para Testear: ⭐⭐⭐⭐☆ (4/5)
- Mocks centralizados facilitan mucho
- Test-Setup.ps1 es brillante
- Algunos archivos tienen dependencias complejas
- Git mocking requiere workarounds

### Documentación: ⭐⭐⭐⭐☆ (4/5)
- PROMPT_COVERAGE.md excelente
- Ejemplos de referencia buenos
- Falta documentación de algunos mocks específicos

---

## 💬 Recomendaciones Finales

1. **Mantén el momentum** - Los archivos fáciles dan motivación
2. **Commits frecuentes** - Cada archivo que llegue a 80%
3. **No te quedes atascado** - Si un archivo es muy complejo, pasa al siguiente y vuelve después
4. **Usa los ejemplos** - `ArrayHelper.Tests.ps1` es una joya
5. **Pregunta cuando dudes** - El patrón SOLID es estricto pero claro

---

## 📞 Si te atascas...

### Problema: "No sé cómo mockear X"
**Solución**: Busca en `tests/Mocks/` si ya existe un mock similar

### Problema: "Type casting error con interfaces"
**Solución**: Usa la clase real con dependencias null, luego `Add-Member -Force` para sobrescribir métodos

### Problema: "Git mock no funciona"
**Solución**: Revisa `GitReadService.Tests.ps1` líneas 5-30, sigue ese patrón EXACTO

### Problema: "Coverage no sube"
**Solución**: Ejecuta con `-ShowUncovered` para ver líneas exactas que faltan

---

## ✅ Checklist de calidad antes de commit

- [ ] Todos los tests del archivo pasan
- [ ] Archivo alcanza 80%+ de cobertura
- [ ] Tests siguen patrón AAA
- [ ] Edge cases cubiertos (null, empty, errors)
- [ ] Nombres descriptivos
- [ ] Tests independientes (BeforeEach usado)
- [ ] No dependencias externas reales
- [ ] Verificado con `npm run test:coverage`

---

**¡Éxito! El proyecto está en excelente estado. Solo necesita más tests.** 🚀

*Última actualización: 31 Enero 2026*
