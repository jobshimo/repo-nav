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

## Before Committing

Run the validation script:

```powershell
.\scripts\Validate-Project.ps1
```

This checks:
- ✅ Syntax errors
- ✅ Missing imports
- ✅ Orphan files
- ✅ Build succeeds

## Testing

### Development Version
```powershell
.\repo-nav.ps1
```

### Bundle Version
```powershell
.\Build-Bundle.ps1
.\dist\repo-nav-bundle.ps1
```

### Quick Test
```powershell
.\scripts\Test-Dev.ps1
```

## Pull Request Checklist

- [ ] `Validate-Project.ps1` passes
- [ ] Code follows naming conventions
- [ ] New files added to `_index.ps1`
- [ ] Translations added for user-facing text
- [ ] No `Write-Host` in services (use Renderer)
