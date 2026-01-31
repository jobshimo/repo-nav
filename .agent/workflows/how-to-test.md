---
description: How to write SOLID tests using Pester and Interfaces
---
# How to Test in repo-nav

We strictly follow SOLID principles and use Pester 5 for testing. We avoid fragile "patching" of objects (using `Add-Member` on live objects) in favor of **Dependency Injection** with Interfaces and Test Doubles (Mocks/Stubs).

## 1. Philosophy
- **Clean Code**: Tests are code. They must be readable and maintainable.
- **Dependency Inversion**: Classes should depend on Interfaces, not concrete implementations.
- **Pure Pester**: Use standard Pester mocks for global commands (`Get-ChildItem`, `git`). Use Class Mocks for dependencies.

## 2. Directory Structure
- `tests/Pester/Unit`: Unit tests isolated from the system.
- `tests/Pester/Integration`: Tests that verify flow between components.
- `tests/Mocks`: Reusable Mock classes (e.g., `MockRepositoryManager.ps1`).

## 3. How to Mock a Dependency

Instead of using `Add-Member` to overwrite a method on a real object, use an Interface and a Mock Class.

### Bad Pattern (Do Not Use)
```powershell
$realService = [RealService]::new()
$realService | Add-Member -MemberType ScriptMethod -Name "GetData" -Value { return "Fake" } -Force
```

### Good Pattern (SOLID)

**1. Define the Interface (src/Core/Interfaces/IYourService.ps1)**
```powershell
interface IYourService {
    [string] GetData()
}
```

**2. Create a Mock Class (tests/Mocks/MockYourService.ps1)**
```powershell
class MockYourService : IYourService {
    [string] $ReturnValue
    
    MockYourService([string]$val) { $this.ReturnValue = $val }

    [string] GetData() {
        return $this.ReturnValue
    }
}
```

**3. Use in Test**
```powershell
$mock = [MockYourService]::new("Fake Data")
$consumer = [ConsumerClass]::new($mock) # Dependency Injection
```

## 4. Pester Best Practices
- Use `BeforeAll` to load types.
- Use `Context` to group related scenarios.
- Use `It` for single assertions.
- Use `Should` for assertions.

## 5. Running Tests
Run all tests with coverage:
```powershell
./scripts/Test-WithCoverage.ps1
```
