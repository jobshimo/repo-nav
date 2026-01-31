---
description: How to refactor PowerShell 5.1 code for Testability and SOLID
---

This workflow guides you through refactoring legacy PowerShell code to be testable, respecting SOLID principles and PowerShell 5.1 constraints (Parse Time vs Runtime).

## 1. Analyze Dependencies
Identify the class you want to refactor. List its "hard" dependencies (e.g., `Start-Process`, `Write-Host`, `[UIRenderer]`).
- If it calls system cmdlets (`Start-Job`, `Get-Content`), it needs a Service Abstraction.
- If it calls UI methods causing side effects, it needs an Interface Abstraction.

## 2. Extract Interfaces (Base Class Pattern)
PowerShell 5.1 doesn't support the `interface` keyword natively in scripts. Use an abstract base class instead.
1. Create `src/Core/Interfaces/I[Name].ps1`.
2. Define the class with empty virtual methods.
```powershell
class IMyService {
    [void] DoSomething([string]$arg) {} # Virtual method
}
```
3. Update `repo-nav.ps1` to load this interface **before** the concrete implementation.

## 3. Implement Service / Wrapper
Create the concrete implementation inheriting from the interface.
```powershell
class MyService : IMyService {
    [void] DoSomething([string]$arg) {
        # Actual logic here
    }
}
```
**Important**: Register the new service in `src/Startup/ServiceRegistry.ps1` and `src/App/AppBuilder.ps1`.

## 4. Refactor Consumer (Dependency Injection)
Update the consumer class (e.g., Command/Controller) to accept the *Interface* in the constructor, not the concrete type.
```powershell
class MyCommand {
    [IMyService] $Service
    MyCommand([IMyService]$service) {
        $this.Service = $service
    }
}
```

## 5. Create Tests with Dynamic Mocks
Pester cannot mock classes that are already loaded if you don't use the Dynamic Mock pattern.
1. Use `tests/Test-Setup.ps1` to load the environment.
2. In `BeforeAll`, define a **Dynamic Mock Class** using `Invoke-Expression` to bypass Parse Time errors.
```powershell
BeforeAll {
    . "$PSScriptRoot/../../Test-Setup.ps1"
    
    # Define Mock dynamically
    $mockCode = @'
    class MockMyService : IMyService {
        [void] DoSomething([string]$arg) { 
            # Track call or do nothing 
        }
    }
'@
    Invoke-Expression $mockCode
}
```
3. Instantiate the consumer with the mock: `[MyCommand]::new([MockMyService]::new())`.

## 6. Verify
Run `Invoke-Pester` on your new test file.
