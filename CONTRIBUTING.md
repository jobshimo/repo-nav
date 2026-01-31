# Contributing to repo-nav

Thank you for your interest in contributing to repo-nav! This document provides guidelines and conventions to maintain code quality.

## Project Structure

```
repo-nav/
├── repo-nav.ps1          # Main entry point (imports only)
├── Build-Bundle.ps1      # Distribution builder
├── Setup.ps1             # User installation wizard
├── src/
│   ├── Config/           # Constants, color palettes
│   ├── Models/           # Data models (immutable)
│   ├── Services/         # Business logic services
│   ├── Core/
│   │   ├── Commands/     # Key-triggered commands
│   │   ├── Engine/       # Main loop, input handler
│   │   ├── Flows/        # Multi-step workflows
│   │   ├── Services/     # Core managers
│   │   ├── State/        # Application state
│   │   └── Interfaces/   # Contracts
│   ├── UI/
│   │   ├── Base/         # Console helpers
│   │   ├── Components/   # Reusable UI elements
│   │   ├── Controllers/  # Complex UI with state
│   │   ├── Views/        # Full-screen displays
│   │   └── Renderers/    # Specialized renderers
│   ├── Startup/          # Service registry, app builder
│   └── Resources/
│       └── i18n/         # Translations (en.json, es.json)
├── scripts/              # Development utilities
├── dist/                 # Distribution output (generated)
└── .agent/workflows/     # AI assistant workflows
```

## Layer Dependencies

```
Config → Models → Services → UI → Commands → Flows → Engine → Startup
```

Each layer can only depend on layers to its left.

## Coding Conventions

### Naming

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `UserPreferencesService` |
| Methods | PascalCase | `LoadPreferences()` |
| Variables | camelCase | `$currentPath` |
| Constants | UPPER_SNAKE | `KEY_ENTER` |
| Files | PascalCase | `PathManager.ps1` |

### Class Structure

```powershell
<#
.SYNOPSIS
    Brief description.
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Single responsibility
    - DIP: Dependencies injected
#>

class MyService {
    # Properties first
    [Type] $Property
    
    # Constructor
    MyService([Type]$dependency) {
        $this.Property = $dependency
    }
    
    # Public methods
    [ReturnType] PublicMethod([ParamType]$param) {
        # Implementation
    }
    
    # Private helpers (use 'hidden' keyword)
    [ReturnType] hidden PrivateHelper() {
        # Implementation
    }
}
```

### Error Handling

```powershell
# Use try/catch for risky operations
try {
    $result = $this.RiskyOperation()
} catch {
    # Log but don't crash
    $this.Logger.LogError($_)
    return $null
}

# Use null guards for optional dependencies
if ($null -ne $this.OptionalService) {
    $this.OptionalService.DoSomething()
}
```

### UI Patterns

```powershell
# Always manage cursor state
try {
    $this.Console.HideCursor()
    # Interactive UI...
} finally {
    $this.Console.ShowCursor()
}

# Use OptionSelector for lists
$config = [SelectionOptions]::new()
$config.Title = $this.Loc.Get("MyView.Title")  # Always localize!
$config.Options = @(...)
$result = $this.OptionSelector.Show($config)
```

## Adding New Features

See `.agent/workflows/` for step-by-step guides:

- `add-command.md` - Add keyboard command
- `add-service.md` - Add business service
- `add-ui-component.md` - Add UI element

## Data Flow Architecture

Understanding how data flows through the application:

```
┌─────────────────────────────────────────────────────────────┐
│                        USER INPUT                            │
│                     (Keyboard Press)                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    InputHandler                              │
│              (Receives raw key press)                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   CommandFactory                             │
│        (Finds matching command via CanExecute())             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              INavigationCommand.Execute()                    │
│         (NavigationCommand, ExitCommand, etc.)               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   CommandContext                             │
│    ┌────────────────────────────────────────────┐            │
│    │  State        → NavigationState            │            │
│    │  RepoManager  → RepositoryManager          │            │
│    │  Renderer     → UIRenderer                 │            │
│    │  Console      → ConsoleHelper              │            │
│    │  Services     → Various services           │            │
│    └────────────────────────────────────────────┘            │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                  │
        ▼                                  ▼
┌─────────────────┐              ┌─────────────────┐
│ NavigationState │              │ RepositoryMgr   │
│  (Sets flags)   │              │   GitService    │
│  ● Dirty flags  │              │   NpmService    │
│  ● Index change │              │   etc.          │
└────────┬────────┘              └────────┬────────┘
         │                                 │
         │         ┌───────────────────────┘
         │         │
         ▼         ▼
┌─────────────────────────────────────────────────────────────┐
│              RenderOrchestrator.RenderIfNeeded()             │
│        (Checks dirty flags → renders only what changed)      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      UIRenderer                              │
│           (Console output with colors)                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    SCREEN OUTPUT                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Concepts:

- **Command Pattern**: Each key press → Command object → Execute()
- **Dirty Flags**: NavigationState tracks what changed to optimize rendering
- **Dependency Injection**: CommandContext provides all services to commands
- **Single Responsibility**: Each layer does one thing well

## Before Committing

### Automated Validation

Install the pre-push hook to automatically run checks before pushing:

```powershell
.\scripts\Install-PrePushHook.ps1
```

This will block pushes if:
- ❌ Syntax errors exist
- ❌ Tests fail
- ❌ Import chain is broken

### Manual Validation

Or run validation manually:

```powershell
.\scripts\Validate-Project.ps1
.\tests\Run-Tests.ps1
```

This checks:
- ✅ Syntax errors
- ✅ Missing imports
- ✅ Orphan files
- ✅ Build succeeds
- ✅ All unit tests pass

## Testing
     
### Running Tests (Pester)
     
We use **Pester** for Unit and Integration testing.
     
**Run all tests:**
```powershell
Invoke-Pester -Path .\tests\Pester\
```
     
**Run specific test file:**
```powershell
Invoke-Pester -Path .\tests\Pester\Unit\Services.Tests.ps1
```
     
### Legacy Tests
Legacy tests (manual assertions) are located in `tests/*.ps1` (excluding `Pester/` folder).
They can be run via:
```powershell
.\tests\Run-Tests.ps1
```

### Development Version
```powershell
.\repo-nav.ps1
```

### Bundle Version
```powershell
.\Build-Bundle.ps1
.\dist\repo-nav-bundle.ps1
```

## Pull Request Checklist

- [ ] `Invoke-Pester` passes (all Pester tests)
- [ ] `Validate-Project.ps1` passes
- [ ] `Run-Tests.ps1` passes (legacy tests)
- [ ] Code follows naming conventions
- [ ] New files added to `_index.ps1`
- [ ] Translations added for user-facing text (en.json, es.json)
- [ ] No `Write-Host` in services (use Renderer)
- [ ] Added unit tests for new functionality using Pester
- [ ] Error handling uses `OperationResult` pattern

## Writing Tests

### Pester Structure (Recommended)
Place new tests in `tests/Pester/Unit` or `tests/Pester/Integration`.

```powershell
# tests/Pester/Unit/MyService.Tests.ps1
using module "..\..\TestHelper.psm1"

Describe "MyService" {
    BeforeAll {
        # Load dependencies
        $srcRoot = Resolve-Path "$PSScriptRoot\..\..\..\src"
        . "$srcRoot\Services\MyService.ps1"
    }

    It "Does something correctly" {
        $service = [MyService]::new()
        $service.DoSomething() | Should -Be "ExpectedValue"
    }
}
```

### Legacy Test Structure
(Deprecated for new tests, see existing files for reference)
