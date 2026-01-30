---
description: How to add a new service to repo-nav
---

# Adding a New Service

## Prerequisites
- Understand the Single Responsibility Principle
- Know if service needs dependencies

## Steps

### 1. Create the Service File

Create `src/Services/YourService.ps1`:

```powershell
<#
.SYNOPSIS
    YourService - Brief description.
    
.DESCRIPTION
    Following SOLID principles:
    - SRP: Only handles X responsibility
    - DIP: Depends on abstractions via constructor injection
#>

class YourService {
    # Dependencies (injected via constructor)
    [UserPreferencesService] $PreferencesService
    
    # Constructor with dependency injection
    YourService([UserPreferencesService]$preferencesService) {
        $this.PreferencesService = $preferencesService
    }
    
    # Public methods
    [object] DoSomething([string]$param) {
        # Implementation
        return $result
    }
}
```

### 2. Register in _index.ps1

Add to `src/Services/_index.ps1`:

```powershell
. "$servicesPath\YourService.ps1"
```

### 3. Register in AppBuilder

Edit `src/App/AppBuilder.ps1`:

```powershell
# Create service (after its dependencies)
$yourService = [YourService]::new($preferencesService)
[ServiceRegistry]::Register('YourService', $yourService)
```

### 4. Add to Context (if needed)

If commands need access, add to the context object in `AppBuilder.ps1`:

```powershell
return [PSCustomObject]@{
    # ... existing services
    YourService = $yourService
}
```

## Verification

// turbo
1. Run `.\repo-nav.ps1` to test in development
2. Run `.\Build-Bundle.ps1` to verify bundle builds

## Best Practices

### Dependency Injection
Always inject dependencies instead of creating them:

```powershell
# ❌ Bad - tight coupling
class BadService {
    [UserPreferencesService] $Prefs = [UserPreferencesService]::new()
}

# ✅ Good - loose coupling
class GoodService {
    [UserPreferencesService] $Prefs
    GoodService([UserPreferencesService]$prefs) {
        $this.Prefs = $prefs
    }
}
```

### Null Guards
Always check for null dependencies:

```powershell
if ($null -ne $this.PreferencesService) {
    $prefs = $this.PreferencesService.LoadPreferences()
}
```

### Error Handling
Use try/catch for operations that might fail:

```powershell
try {
    $result = $this.RiskyOperation()
} catch {
    # Log error but don't crash
    return $null
}
```
