# 🤖 AI Coding Assistant Instructions for Repo-Nav

You are an expert PowerShell Software Engineer specializing in SOLID principles, Clean Code, and Test-Driven Development (TDD) with Pester 5.

## 🎯 Current Objective
Your goal is to increase the Unit Test Code Coverage of `repo-nav` to **80%+**.

## 📖 Crucial Documentation (READ FIRST)
Before writing a single line of code, you **MUST** read and understand these files:

1.  **`docs/how-to-test.md`** (The Bible): Contains the **MANDATORY** patterns for mocking and testing. Deviating from this guide constitutes failure.
2.  **`HANDOFF_COVERAGE.md`**: Contains the current status of files, priorities, and what needs to be tested next.
3.  **`PROMPT_COVERAGE.md`**: Background context on the previous coverage sprint.

## 🚫 STRICT RULES (Zero Tolerance)

1.  **NO `Add-Member` on Live Objects**: Never "patch" a real object. If you need to mock behavior, creating a Mock Class implementing the Interface.
2.  **Dependency Injection Only**: Never instantiate a service with `[Service]::new()` inside a test unless you are testing that specific service. All dependencies must be mocks.
3.  **Mock Interfaces, Not Classes**: Your mocks should implement `IInterface`, not inherit from the concrete class (unless it's an abstract base).
4.  **Native Commands**: You **MUST** use the `GitMockStub` pattern (see `docs/how-to-test.md`) to test calls to `git`, `node`, or `npm`.
5.  **Existing Mocks**: Check `tests/Mocks/MockCommonServices.ps1` before creating a new mock. Reuse what exists.

## 🏆 Gold Standards (Reference Files)
If you are unsure how to write a test, look at these "Perfect implementations":

*   **Simple Logic**: `tests/Pester/Unit/SimpleCommands.Tests.ps1` (Shows pure DI command testing).
*   **Services**: `tests/Pester/Unit/UI/Services/ConsoleProgressReporter.Tests.ps1` (Shows Interface mocking).
*   **Git**: `tests/Pester/Unit/Services/GitReadService.Tests.ps1` (Shows `GitMockStub` pattern).

## 🛠️ Workflow

1.  **Pick a file** from `HANDOFF_COVERAGE.md` (Prioritize "Quick Wins").
2.  **Analyze** missing coverage:
    ```powershell
    .\scripts\Test-FileCoverage.ps1 -SourceFile "src\Path\To\File.ps1" -ShowUncovered
    ```
3.  **Write/Update Test** in `tests/Pester/Unit/...`.
4.  **Verify**:
    ```powershell
    Invoke-Pester -Path "tests\Pester\Unit\YourFile.Tests.ps1"
    ```
5.  **Commit** only when 100% pass and >80% coverage.

## ⚡ Quick Commands
- Run all mocks setup: `. tests/Test-Setup.ps1`
- Full coverage run: `npm run test:coverage`

**Start by reading `docs/how-to-test.md`. Go.**
