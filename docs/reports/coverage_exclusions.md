# Exclusiones de Cobertura de Tests

**Fecha:** 1 de febrero de 2026  
**Configuración:** `PesterConfig.json`

---

## 📋 Resumen

Se han configurado exclusiones automáticas para archivos que **no necesitan tests** porque no contienen lógica ejecutable.

## 🚫 Archivos Excluidos

### Estadísticas
| Categoría | Cantidad | Patrón |
|-----------|----------|--------|
| **Interfaces** | 28 archivos | `**/Interfaces/*.ps1` |
| **Archivos _index.ps1** | 8 archivos | `**/*/_index.ps1` |
| **Resources** | 0 archivos | `**/Resources/**/*.ps1` |
| **Dev Tools** | 1 archivo | `**/Dev/*.ps1` |
| **TOTAL EXCLUIDOS** | **37 archivos** | - |

---

## 🎯 Razones de Exclusión

### 1. Interfaces (`src/Core/Interfaces/*.ps1`)

**¿Por qué se excluyen?**
- Son definiciones de contratos (clases abstractas)
- No contienen lógica ejecutable, solo firmas de métodos
- Se validan indirectamente al testear las implementaciones

**Ejemplo:**
```powershell
# src/Core/Interfaces/IOptionSelector.ps1
class IOptionSelector : ConsoleView {
    [object] Show([SelectionOptions]$config) { return $null }
    # Solo definición, no implementación
}
```

**Validación:** 
- ✅ Las implementaciones reales (`OptionSelector.ps1`) SÍ tienen tests
- ✅ Los mocks implementan estas interfaces y se usan en tests

**Interfaces excluidas:**
- IOptionSelector.ps1
- IConsoleHelper.ps1
- IGitService.ps1
- IRepositoryManager.ps1
- IAliasManager.ps1
- IFavoriteService.ps1
- ISearchService.ps1
- IUIRenderer.ps1
- IConfigurationService.ps1
- IUserPreferencesService.ps1
- ILocalizationService.ps1
- IJobService.ps1
- INpmService.ps1
- IProgressIndicator.ps1
- IProgressReporter.ps1
- ... (28 total)

---

### 2. Archivos `_index.ps1` (Bootstrapping)

**¿Por qué se excluyen?**
- Solo contienen dot-sourcing (`. "$PSScriptRoot/Archivo.ps1"`)
- No tienen lógica de negocio
- Se validan implícitamente al cargar el proyecto

**Ejemplo:**
```powershell
# src/Services/_index.ps1
. "$PSScriptRoot/AliasManager.ps1"
. "$PSScriptRoot/ConfigurationService.ps1"
. "$PSScriptRoot/ErrorHandler.ps1"
# ... solo importaciones
```

**Validación:**
- ✅ `Test-Setup.ps1` carga todo el proyecto y falla si hay errores
- ✅ Cualquier error de sintaxis se detecta al ejecutar tests

**Archivos _index.ps1 excluidos:**
- src/Config/_index.ps1
- src/Models/_index.ps1
- src/Services/_index.ps1
- src/Startup/_index.ps1
- src/UI/_index.ps1
- src/Core/Commands/_index.ps1
- src/Core/Flows/_index.ps1
- src/Core/Engine/_index.ps1

---

### 3. Resources (`src/Resources/**/*.ps1`)

**¿Por qué se excluyen?**
- Archivos de datos (i18n, configuración estática)
- No contienen código PowerShell ejecutable
- Son archivos JSON/YAML cargados dinámicamente

**Actualmente:** 0 archivos .ps1 en Resources (solo hay archivos de datos).

---

### 4. Dev Tools (`src/Dev/*.ps1`)

**¿Por qué se excluyen?**
- Herramientas de desarrollo temporal
- No forman parte del código de producción
- Usadas solo por desarrolladores

**Ejemplo:**
```powershell
# src/Dev/DevToolsCommand.ps1
# Herramienta para debugging/testing manual
```

---

## 📊 Impacto en Cobertura

### Antes de Exclusiones
- Total archivos en `src/`: ~150 archivos
- Archivos evaluados para cobertura: ~150
- **Objetivo de cobertura era artificialmente bajo** por interfaces sin tests

### Después de Exclusiones
- Total archivos en `src/`: ~150 archivos
- Archivos excluidos: 37
- **Archivos evaluados para cobertura: ~113 archivos**
- **Objetivo de cobertura más realista y relevante**

### Mejora
- ✅ La métrica de 80% ahora es sobre código **real ejecutable**
- ✅ No perdemos tiempo testeando definiciones abstractas
- ✅ Cobertura más significativa y accionable

---

## 🔧 Configuración Técnica

### PesterConfig.json
```json
{
    "CodeCoverage": {
        "Enabled": true,
        "Path": [ "src" ],
        "ExcludeTests": [
            "**/*/_index.ps1",
            "**/Interfaces/*.ps1",
            "**/Resources/**/*.ps1",
            "**/Dev/*.ps1"
        ],
        "OutputFormat": "Jacoco",
        "OutputPath": "coverage.xml",
        "CoveragePercentTarget": 80
    }
}
```

### Verificación
```powershell
# Ver configuración actual
Get-Content PesterConfig.json | ConvertFrom-Json | 
    Select-Object -ExpandProperty CodeCoverage

# Ejecutar tests con exclusiones
.\scripts\Test-WithCoverage.ps1
```

---

## ✅ Criterios para Exclusión

### ¿Cuándo EXCLUIR un archivo?
- ✅ No contiene lógica ejecutable (solo definiciones)
- ✅ No tiene decisiones (if/switch/loops)
- ✅ No tiene cálculos ni transformaciones
- ✅ Es puro bootstrapping/carga
- ✅ Es código de desarrollo (no producción)

### ¿Cuándo NO excluir?
- ❌ Tiene cualquier lógica de negocio
- ❌ Hace validaciones o transformaciones
- ❌ Contiene algoritmos o decisiones
- ❌ Es parte del flujo de producción

---

## 🎓 Lecciones Aprendidas

### Problema Original
Al intentar alcanzar 80% de cobertura en `NpmCommand`, nos dimos cuenta de que:
- Las interfaces afectaban negativamente la métrica
- No tiene sentido testear definiciones abstractas
- El objetivo de 80% era sobre código que incluía "no testeable"

### Solución
- Configurar exclusiones explícitas en Pester
- Documentar claramente qué se excluye y por qué
- Mantener el objetivo de 80% pero sobre código **relevante**

### Beneficios
1. **Métrica más realista:** 80% sobre código ejecutable real
2. **Ahorro de tiempo:** No escribir tests innecesarios
3. **Claridad:** Todos saben qué archivos necesitan tests
4. **Mantenibilidad:** Nuevas interfaces/index no requieren tests

---

## 📝 Recomendaciones para Futuras AIs

1. **Antes de crear tests para un archivo:** Verifica si está en las exclusiones
2. **Si encuentras una interfaz sin tests:** Es normal, está excluida
3. **Si añades una nueva interfaz:** No necesitas crear tests para ella
4. **Si modificas `_index.ps1`:** No necesitas tests adicionales
5. **Si quieres excluir más archivos:** Edita `PesterConfig.json` y documenta aquí

### Comando Rápido de Verificación
```powershell
# Ver si un archivo está excluido
$file = "src/Core/Interfaces/INewInterface.ps1"
$config = Get-Content PesterConfig.json | ConvertFrom-Json
$excluded = $config.CodeCoverage.ExcludeTests

foreach ($pattern in $excluded) {
    if ($file -like $pattern.Replace('**', '*')) {
        Write-Host "✅ Archivo excluido: $file" -ForegroundColor Green
        return
    }
}
Write-Host "⚠️ Archivo NO excluido: $file (necesita tests)" -ForegroundColor Yellow
```

---

## 📚 Referencias

- **Configuración:** [PesterConfig.json](../../PesterConfig.json)
- **Guía de Testing:** [how-to-test.md](../../.agent/workflows/how-to-test.md)
- **Reporte de Cobertura:** [npmcommand_coverage_report.md](npmcommand_coverage_report.md)

---

**Última actualización:** 1 de febrero de 2026  
**Responsable:** Sistema de testing automatizado  
**Versión:** 1.0
