# Estrategia de Refactorización: NavigationLoop.ps1 → Arquitectura OOP/SOLID

## 📋 Análisis del Problema Actual

### Estado Actual
`NavigationLoop.ps1` es una función monolítica de ~409 líneas que:
- ❌ Gestiona el estado de navegación (índice seleccionado, running)
- ❌ Maneja toda la lógica de input (teclado, eventos)
- ❌ Coordina renderizado completo de la UI
- ❌ Ejecuta lógica de negocio (editar alias, clonar, instalar npm)
- ❌ Gestiona el ciclo de vida de la aplicación
- ❌ Tiene código duplicado masivo (refresh & redraw)

### Violaciones de SOLID
1. **SRP**: Responsabilidades múltiples (input, render, state, business logic)
2. **OCP**: Imposible extender sin modificar código existente
3. **DIP**: Acoplamiento directo con helpers y funciones procedurales
4. **Testabilidad**: Imposible testear sin ejecutar el loop completo

---

## 🎯 Arquitectura Objetivo

### Principios Guía
1. **Command Pattern**: Cada tecla = un comando independiente
2. **State Pattern**: Estado de navegación encapsulado
3. **Strategy Pattern**: Renderizado según contexto
4. **Dependency Injection**: Todas las dependencias inyectadas
5. **Single Responsibility**: Cada clase hace UNA cosa bien

### Nueva Estructura de Clases

```
src/Core/
├── NavigationLoop.ps1              [REFACTORIZADO]
│   └── Orquestador simple (< 50 líneas)
│
├── NavigationState.ps1             [NUEVO]
│   └── Estado: índice, repos, running, dirty flags
│
├── InputHandler.ps1                [NUEVO]
│   └── Lee y despacha comandos
│
└── Commands/                       [NUEVO DIRECTORIO]
    ├── INavigationCommand.ps1      [INTERFACE]
    ├── NavigationCommand.ps1       [UP/DOWN]
    ├── RepositoryCommand.ps1       [ENTER]
    ├── AliasCommand.ps1            [E/R]
    ├── NpmCommand.ps1              [I/X]
    ├── GitCommand.ps1              [L/G]
    ├── RepositoryManagementCommand.ps1 [C/DELETE]
    ├── FavoriteCommand.ps1         [F]
    ├── PreferencesCommand.ps1      [U]
    └── ExitCommand.ps1             [Q/ESC]

src/Services/
├── CommandFactory.ps1              [NUEVO]
│   └── Crea comandos según tecla presionada
│
└── RenderOrchestrator.ps1          [NUEVO]
    └── Decide qué/cómo renderizar (full/partial)
```

---

## 📐 Diseño de Clases

### 1. NavigationState (Estado)
```powershell
class NavigationState {
    [int] $SelectedIndex
    [array] $Repositories
    [bool] $IsRunning
    [bool] $RequiresFullRedraw
    [bool] $RequiresPartialRedraw
    [int] $PreviousIndex
    
    # Constructor
    NavigationState([array]$repos) { }
    
    # State management
    [void] SelectNext() { }
    [void] SelectPrevious() { }
    [void] Stop() { }
    [void] MarkForFullRedraw() { }
    [void] MarkForPartialRedraw() { }
    [void] ClearRedrawFlags() { }
    [object] GetSelectedRepository() { }
    [void] UpdateRepositories([array]$repos) { }
}
```

### 2. INavigationCommand (Interface)
```powershell
interface INavigationCommand {
    [bool] CanExecute([NavigationState]$state)
    [void] Execute([NavigationState]$state, [hashtable]$context)
    [string] GetDescription()
}
```

### 3. Ejemplo: NavigationCommand (UP/DOWN)
```powershell
class NavigationCommand : INavigationCommand {
    [string] $Direction  # "Up" or "Down"
    
    NavigationCommand([string]$direction) {
        $this.Direction = $direction
    }
    
    [bool] CanExecute([NavigationState]$state) {
        return $true  # Siempre puede navegar
    }
    
    [void] Execute([NavigationState]$state, [hashtable]$context) {
        if ($this.Direction -eq "Up") {
            $state.SelectPrevious()
        } else {
            $state.SelectNext()
        }
        $state.MarkForPartialRedraw()
    }
    
    [string] GetDescription() {
        return "Navigate $($this.Direction)"
    }
}
```

### 4. CommandFactory (Factory)
```powershell
class CommandFactory {
    # Dependencies
    [RepositoryManager] $RepoManager
    [ConsoleHelper] $Console
    [UIRenderer] $Renderer
    [ColorSelector] $ColorSelector
    [OptionSelector] $OptionSelector
    [string] $BasePath
    
    # Constructor con DI
    CommandFactory($repoManager, $console, $renderer, $colorSelector, $optionSelector, $basePath) { }
    
    # Factory method
    [INavigationCommand] CreateCommand([int]$virtualKeyCode) {
        switch ($virtualKeyCode) {
            ([Constants]::KEY_UP_ARROW) { 
                return [NavigationCommand]::new("Up") 
            }
            ([Constants]::KEY_DOWN_ARROW) { 
                return [NavigationCommand]::new("Down") 
            }
            ([Constants]::KEY_ENTER) { 
                return [RepositoryCommand]::new($this.Console, $this.Renderer) 
            }
            ([Constants]::KEY_E) { 
                return [AliasEditCommand]::new($this.RepoManager, $this.ColorSelector, $this.BasePath) 
            }
            # ... resto de comandos
            default { 
                return $null 
            }
        }
    }
}
```

### 5. RenderOrchestrator (Renderizado Inteligente)
```powershell
class RenderOrchestrator {
    [UIRenderer] $Renderer
    [ConsoleHelper] $Console
    
    RenderOrchestrator([UIRenderer]$renderer, [ConsoleHelper]$console) { }
    
    [void] RenderFull([NavigationState]$state) {
        # Renderizado completo (header, menu, todos los repos, footer)
    }
    
    [void] RenderPartial([NavigationState]$state) {
        # Renderizado parcial (solo items afectados + footer)
    }
    
    [void] RenderIfNeeded([NavigationState]$state) {
        if ($state.RequiresFullRedraw) {
            $this.RenderFull($state)
            $state.ClearRedrawFlags()
        }
        elseif ($state.RequiresPartialRedraw) {
            $this.RenderPartial($state)
            $state.ClearRedrawFlags()
        }
    }
}
```

### 6. InputHandler (Manejador de Input)
```powershell
class InputHandler {
    [ConsoleHelper] $Console
    [CommandFactory] $CommandFactory
    
    InputHandler([ConsoleHelper]$console, [CommandFactory]$factory) { }
    
    [INavigationCommand] WaitForCommand() {
        $key = $this.Console.ReadKey()
        return $this.CommandFactory.CreateCommand($key.VirtualKeyCode)
    }
}
```

### 7. NavigationLoop (Refactorizado - Orquestador)
```powershell
function Start-NavigationLoop {
    param(
        [Parameter(Mandatory = $true)] $RepoManager,
        [Parameter(Mandatory = $true)] $Renderer,
        [Parameter(Mandatory = $true)] $Console,
        [Parameter(Mandatory = $true)] $ColorSelector,
        [Parameter(Mandatory = $true)] $OptionSelector,
        [Parameter(Mandatory = $true)] [string]$BasePath
    )
    
    # Initialize
    $RepoManager.LoadRepositories($BasePath)
    $repos = $RepoManager.GetRepositories()
    
    if ($repos.Count -eq 0) {
        $Renderer.RenderError("No repositories found.")
        return
    }
    
    # Create components
    $state = [NavigationState]::new($repos)
    $renderOrchestrator = [RenderOrchestrator]::new($Renderer, $Console)
    $commandFactory = [CommandFactory]::new($RepoManager, $Console, $Renderer, $ColorSelector, $OptionSelector, $BasePath)
    $inputHandler = [InputHandler]::new($Console, $commandFactory)
    
    # Prepare context
    $context = @{
        RepoManager = $RepoManager
        BasePath = $BasePath
    }
    
    try {
        $Console.HideCursor()
        
        # Initial render
        $state.MarkForFullRedraw()
        $renderOrchestrator.RenderIfNeeded($state)
        
        # Main loop (SIMPLE)
        while ($state.IsRunning) {
            $command = $inputHandler.WaitForCommand()
            
            if ($command -and $command.CanExecute($state)) {
                $command.Execute($state, $context)
                $renderOrchestrator.RenderIfNeeded($state)
            }
        }
    }
    finally {
        $Console.ShowCursor()
    }
}
```

---

## 🛠️ Plan de Acción (15 Pasos)

### FASE 1: Preparación (Sin Breaking Changes)
**Objetivo**: Crear infraestructura nueva sin romper lo existente

#### ✅ Paso 1: Crear Interface INavigationCommand
- **Archivo**: `src/Core/Commands/INavigationCommand.ps1`
- **Acción**: Definir interface con métodos CanExecute/Execute
- **Test**: Import-Module y verificar que carga sin errores
- **Riesgo**: ⚪ Bajo (nuevo archivo)

#### ✅ Paso 2: Crear NavigationState
- **Archivo**: `src/Core/NavigationState.ps1`
- **Acción**: Clase para encapsular estado (índice, repos, flags)
- **Test**: Crear instancia, probar métodos SelectNext/Previous
- **Riesgo**: ⚪ Bajo (nuevo archivo)

#### ✅ Paso 3: Crear RenderOrchestrator
- **Archivo**: `src/Services/RenderOrchestrator.ps1`
- **Acción**: Extraer lógica de renderizado (full/partial) del loop
- **Test**: Renderizado visual manual
- **Riesgo**: ⚪ Bajo (nuevo archivo)

#### ✅ Paso 4: Crear Comando Simple (ExitCommand)
- **Archivo**: `src/Core/Commands/ExitCommand.ps1`
- **Acción**: Implementar comando Q/ESC (el más simple)
- **Test**: Ejecutar manualmente
- **Riesgo**: ⚪ Bajo (prueba de concepto)

#### ✅ Paso 5: Crear NavigationCommand
- **Archivo**: `src/Core/Commands/NavigationCommand.ps1`
- **Acción**: Comandos UP/DOWN arrows
- **Test**: Navegación entre repos
- **Riesgo**: 🟡 Medio (lógica existente)

---

### FASE 2: Comandos de Lectura (Sin Modificar Estado Global)
**Objetivo**: Implementar comandos que NO modifican repos

#### ✅ Paso 6: Crear RepositoryCommand (ENTER)
- **Archivo**: `src/Core/Commands/RepositoryCommand.ps1`
- **Acción**: Abrir repositorio (Set-Location)
- **Test**: Verificar que cambia directorio correctamente
- **Riesgo**: 🟡 Medio

#### ✅ Paso 7: Crear GitCommand (L/G)
- **Archivo**: `src/Core/Commands/GitCommand.ps1`
- **Acción**: Load git status (current/all)
- **Test**: Cargar status sin errores
- **Riesgo**: 🟡 Medio

#### ✅ Paso 8: Crear FavoriteCommand (F)
- **Archivo**: `src/Core/Commands/FavoriteCommand.ps1`
- **Acción**: Toggle favorite
- **Test**: Verificar persistencia
- **Riesgo**: 🟡 Medio

---

### FASE 3: Comandos de Escritura (Modifican Estado)
**Objetivo**: Comandos que modifican repos/configuración

#### ✅ Paso 9: Crear AliasCommand (E/R)
- **Archivo**: `src/Core/Commands/AliasCommand.ps1`
- **Acción**: Edit/Remove alias (wrappea InteractiveHelpers)
- **Test**: Set/remove alias completo
- **Riesgo**: 🟠 Alto (UI interactiva)

#### ✅ Paso 10: Crear NpmCommand (I/X)
- **Archivo**: `src/Core/Commands/NpmCommand.ps1`
- **Acción**: Install/Remove node_modules
- **Test**: npm install en repo real
- **Riesgo**: 🟠 Alto (operaciones de filesystem)

#### ✅ Paso 11: Crear RepositoryManagementCommand (C/DELETE)
- **Archivo**: `src/Core/Commands/RepositoryManagementCommand.ps1`
- **Acción**: Clone/Delete repository
- **Test**: Clonar repo temporal, luego eliminarlo
- **Riesgo**: 🔴 Crítico (puede perder datos)

#### ✅ Paso 12: Crear PreferencesCommand (U)
- **Archivo**: `src/Core/Commands/PreferencesCommand.ps1`
- **Acción**: Abrir menú de preferencias
- **Test**: Cambiar sorting, verificar persistencia
- **Riesgo**: 🟡 Medio

---

### FASE 4: Integración y Reemplazo
**Objetivo**: Conectar todo y eliminar código viejo

#### ✅ Paso 13: Crear CommandFactory
- **Archivo**: `src/Services/CommandFactory.ps1`
- **Acción**: Factory que mapea teclas → comandos
- **Test**: Verificar cada tecla devuelve comando correcto
- **Riesgo**: 🟡 Medio

#### ✅ Paso 14: Crear InputHandler
- **Archivo**: `src/Core/InputHandler.ps1`
- **Acción**: Lee teclas y despacha comandos
- **Test**: Probar con todos los comandos
- **Riesgo**: 🟡 Medio

#### ✅ Paso 15: REFACTORIZAR NavigationLoop
- **Archivo**: `src/Core/NavigationLoop.ps1` (REEMPLAZAR)
- **Acción**: Reducir a ~50 líneas de orquestación
- **Test**: ⚠️ **TEST COMPLETO DE TODA LA APLICACIÓN**
- **Riesgo**: 🔴 Crítico (punto de no retorno)

---

## 🧪 Estrategia de Testing

### Por Cada Paso
```powershell
# Test básico de carga
Import-Module .\src\Core\Commands\ExitCommand.ps1 -Force

# Test de instanciación
$cmd = [ExitCommand]::new($console, $renderer)

# Test de ejecución
$state = [NavigationState]::new($repos)
$cmd.Execute($state, @{})

# Verificación visual
Write-Host "✓ Command executed successfully"
```

### Test de Integración (Paso 15)
```powershell
# Backup del archivo original
Copy-Item src\Core\NavigationLoop.ps1 src\Core\NavigationLoop.ps1.backup

# Ejecutar aplicación completa
.\repo-nav.ps1

# Checklist manual:
# [ ] Navegación UP/DOWN
# [ ] Enter abre repo
# [ ] E edita alias
# [ ] R elimina alias
# [ ] I instala npm
# [ ] X elimina node_modules
# [ ] C clona repo
# [ ] DELETE elimina repo
# [ ] L carga git status
# [ ] G carga todos git status
# [ ] F toggle favorite
# [ ] U preferencias
# [ ] Q/ESC salir
```

---

## ⚠️ Gestión de Riesgos

### Riesgos Principales

#### 1. Breaking Changes en PowerShell
**Problema**: PowerShell es sensible con clases/herencia
**Mitigación**:
- Test inmediato después de cada clase nueva
- Usar `Import-Module -Force` en cada test
- Mantener backup del código original

#### 2. Comportamiento de Console/UI
**Problema**: ReadKey(), Clear, posición cursor pueden fallar
**Mitigación**:
- Testear en terminal real (no VSCode integrated terminal)
- Verificar que $Console.HideCursor() funciona
- Probar renderizado parcial cuidadosamente

#### 3. Estado Compartido
**Problema**: Múltiples comandos modifican $state
**Mitigación**:
- NavigationState es mutable pero controlado
- Comandos NO comparten estado entre sí
- Context hashtable para deps externas

#### 4. InteractiveHelpers Existentes
**Problema**: Funciones procedurales que necesitamos mantener
**Mitigación**:
- Los comandos WRAPPEAN las funciones existentes
- NO reescribir toda la lógica interactiva inmediatamente
- Refactorizar helpers en Fase 2 (futuro)

---

## 📦 Estructura de Archivos Final

```
src/
├── Config/
│   ├── ColorPalette.ps1
│   └── Constants.ps1
│
├── Core/
│   ├── NavigationLoop.ps1          [REFACTORIZADO - 50 líneas]
│   ├── NavigationState.ps1         [NUEVO]
│   ├── InputHandler.ps1            [NUEVO]
│   ├── RepositoryManager.ps1       [EXISTENTE]
│   └── Commands/                   [NUEVO DIRECTORIO]
│       ├── INavigationCommand.ps1
│       ├── NavigationCommand.ps1
│       ├── RepositoryCommand.ps1
│       ├── AliasCommand.ps1
│       ├── NpmCommand.ps1
│       ├── GitCommand.ps1
│       ├── RepositoryManagementCommand.ps1
│       ├── FavoriteCommand.ps1
│       ├── PreferencesCommand.ps1
│       └── ExitCommand.ps1
│
├── Models/
│   ├── AliasInfo.ps1
│   ├── GitStatusModel.ps1
│   └── RepositoryModel.ps1
│
├── Services/
│   ├── AliasManager.ps1
│   ├── ConfigurationService.ps1
│   ├── GitService.ps1
│   ├── InteractiveHelpers.ps1      [EXISTENTE - mantener]
│   ├── NpmHelpers.ps1
│   ├── NpmService.ps1
│   ├── PreferencesHelpers.ps1
│   ├── UserPreferencesService.ps1
│   ├── CommandFactory.ps1          [NUEVO]
│   └── RenderOrchestrator.ps1      [NUEVO]
│
└── UI/
    ├── ColorSelector.ps1
    ├── ConsoleHelper.ps1
    ├── OptionSelector.ps1
    └── UIRenderer.ps1
```

---

## 🎓 Beneficios de la Refactorización

### 1. Mantenibilidad
- ✅ Cada comando es independiente (< 50 líneas)
- ✅ Agregar nueva tecla = crear nuevo comando
- ✅ Modificar comportamiento = editar 1 archivo

### 2. Testabilidad
- ✅ Comandos se pueden testear aisladamente
- ✅ Mock de dependencias sencillo (DI)
- ✅ State management predecible

### 3. Extensibilidad
- ✅ Nuevos comandos sin modificar loop
- ✅ Nuevos tipos de renderizado (Strategy)
- ✅ Nuevas teclas sin switch gigante

### 4. SOLID Compliance
- ✅ **SRP**: 1 comando = 1 responsabilidad
- ✅ **OCP**: Abierto para extensión (nuevos comandos)
- ✅ **LSP**: Todos los comandos son INavigationCommand
- ✅ **ISP**: Interface pequeña y específica
- ✅ **DIP**: Dependencias inyectadas

### 5. Reducción de Código
- ❌ Antes: ~409 líneas monolíticas
- ✅ Después: ~50 líneas orquestación + ~30-40 líneas/comando

---

## 📅 Estimación de Tiempo

| Fase | Pasos | Tiempo Estimado | Riesgo |
|------|-------|-----------------|--------|
| **Fase 1: Preparación** | 1-5 | 2-3 horas | ⚪ Bajo |
| **Fase 2: Comandos Lectura** | 6-8 | 2-3 horas | 🟡 Medio |
| **Fase 3: Comandos Escritura** | 9-12 | 3-4 horas | 🟠 Alto |
| **Fase 4: Integración** | 13-15 | 2-3 horas | 🔴 Crítico |
| **Testing Final** | - | 1-2 horas | 🔴 Crítico |
| **TOTAL** | 15 pasos | **10-15 horas** | - |

---

## 🚀 Siguiente Paso Inmediato

### Recomendación: Empezar con Fase 1, Paso 1
```powershell
# Crear directorio para comandos
New-Item -Path "src\Core\Commands" -ItemType Directory -Force

# Crear interface INavigationCommand
# (Siguiente archivo a crear)
```

**¿Quieres que proceda con el Paso 1 ahora?** 🎯

---

## 📚 Referencias

- **Command Pattern**: https://refactoring.guru/design-patterns/command
- **State Pattern**: https://refactoring.guru/design-patterns/state
- **SOLID Principles**: https://en.wikipedia.org/wiki/SOLID
- **PowerShell Classes**: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes

---

**Documento creado**: 2026-01-23  
**Versión**: 1.0  
**Autor**: GitHub Copilot + Martin Miguel Bernal Garcia
