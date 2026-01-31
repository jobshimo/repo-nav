# How to Test in repo-nav

> **🔥 CRITICAL:** Read the full guide at `docs/how-to-test.md` before writing any tests.

We strictly follow SOLID principles and use Pester 5.

## Quick Cheat Sheet

### 1. Structure
- **Unit Tests**: `tests/Pester/Unit/`
- **Mocks**: `tests/Mocks/` (Re-use existing mocks!)

### 2. Critical Patterns

#### Dependency Injection (The ONLY way)
```powershell
# BAD
$service = [Service]::new() # Real dependencies

# GOOD
$mock = [MockCommonService]::new()
$service = [Service]::new($mock)
```

#### Mocking Git (Native Commands)
You **MUST** use the `GitMockStub` pattern found in `docs/how-to-test.md` section 2.
**DO NOT** try to mock `git` directly without the alias shim.

### 3. Running Tests
```powershell
# Run with coverage
npm run test:coverage
```

See `docs/how-to-test.md` for the full "Strategy 2.0".
