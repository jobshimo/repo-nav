# REPO-NAV

> **Interactive PowerShell repository navigator with aliases, Git integration, and npm management.**

---

## The Story

This project started as a simple PowerShell script to solve a common problem: **quickly identifying and navigating between multiple Git repositories**. The original idea was straightforward — a way to assign short aliases with colors to repositories so you could instantly recognize them in a long list.

What began as a ~200 line utility script has evolved into a full-featured application through the application of **software engineering principles** and an **engineer's mindset**. Despite PowerShell's limitations as a language (no true interfaces, limited OOP support, challenging class syntax), we've built a maintainable, extensible architecture following **SOLID principles**.

The result is what you see now: a **professional-grade CLI tool** that demonstrates how proper software design can transform even a simple script into a robust application.

---

## Features

### Core Navigation
- **Arrow key navigation** through repository list
- **Hierarchical folder support** — navigate into container folders
- **Smart pagination** — adapts to terminal window size
- **Real-time search** — filter repositories as you type

### Repository Management
- **Custom aliases** with configurable colors
- **Favorites system** — pin important repos to the top
- **Clone repositories** directly from URLs
- **Delete repositories** with safety confirmations

### Git Integration
- **Branch information** display
- **Status indicators** — uncommitted changes, unpushed commits
- **Parallel status loading** — load all repos simultaneously
- **Auto-load options** — favorites or all on startup

### npm Integration  
- **Install dependencies** — run `npm install` from the navigator
- **Remove node_modules** — clean up with one keypress
- **Visual indicators** — see which repos have node_modules

### User Experience
- **Localization** — English and Spanish supported
- **Customizable UI** — colors, delimiters, menu visibility
- **Preferences system** — persistent user settings
- **Clean visual design** — consistent, readable interface

---

## Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| **PowerShell** | 5.1+ | **Required** — Uses class syntax and modern features |
| **Git** | Any | *Optional* — Required for Git features |
| **npm** | Any | *Optional* — Required for package management |

---

## Installation

### 1. Clone or Download

```powershell
git clone https://github.com/yourusername/repo-nav.git
cd repo-nav
```

### 2. Run Setup

```powershell
.\Setup.ps1
```

The setup wizard will:
- ✓ Check system requirements (PowerShell, Git, npm)
- ✓ Configure your repositories path
- ✓ Set up a command in your PowerShell profile
- ✓ Create configuration files

### 3. Reload Profile

```powershell
. $PROFILE
```

Or restart your terminal.

### 4. Launch

```powershell
list
```

(or whatever command name you chose during setup)

---

## Controls

| Key | Action | Description |
|-----|--------|-------------|
| `↑` `↓` | Navigate | Move selection up/down |
| `←` `→` | Hierarchy | Enter/exit container folders |
| `Enter` | Open | Navigate to selected repository |
| `Q` / `Esc` | Quit | Exit the navigator |
| `E` | Edit Alias | Set or modify repository alias |
| `R` | Remove Alias | Remove repository alias |
| `F` | Favorite | Toggle favorite status |
| `L` | Load Status | Load Git status for current repo |
| `G` | Load All | Load Git status for all repos |
| `I` | Install | Run `npm install` |
| `X` | Remove | Delete `node_modules` folder |
| `C` | Clone | Clone new repository from URL |
| `N` | New Folder | Create a new folder |
| `Del` | Delete | Delete repository (with confirmations) |
| `/` | Search | Open search interface |
| `P` | Preferences | Open preferences menu |

---

## Configuration

### Setup Files

| File | Purpose | Git Status |
|------|---------|------------|
| `.repo-config.json` | Your repositories path and username | Ignored |
| `.repo-aliases.json` | Repository aliases and favorites | Ignored |
| `.repo-preferences.json` | UI preferences and settings | Ignored |
| `.repo-config.example.json` | Template for config | Tracked |

### Example Config

```json
{
  "reposBasePath": "C:\\Users\\YourUser\\repos",
  "userName": "YourUser"
}
```

---

## Architecture

### Project Structure

```
repo-nav/
├── repo-nav.ps1              # Entry point
├── Setup.ps1                 # Setup wizard
├── README.md
├── src/
│   ├── Config/               # Constants and color palettes
│   ├── Models/               # Data structures (Repository, Alias, GitStatus)
│   ├── Services/             # Business logic layer
│   │   ├── GitService.ps1
│   │   ├── NpmService.ps1
│   │   ├── AliasManager.ps1
│   │   ├── FavoriteService.ps1
│   │   ├── SearchService.ps1
│   │   └── ...
│   ├── UI/                   # Presentation layer
│   │   ├── ConsoleHelper.ps1
│   │   ├── UIRenderer.ps1
│   │   ├── MenuRenderer.ps1
│   │   └── Views/
│   └── Core/                 # Application core
│       ├── NavigationState.ps1
│       ├── RepositoryManager.ps1
│       ├── CommandFactory.ps1
│       └── Commands/         # Command Pattern implementations
└── tests/                    # Test structure (WIP)
```

### Design Principles

This project follows **SOLID principles** adapted for PowerShell:

| Principle | Implementation |
|-----------|----------------|
| **Single Responsibility** | Each class has one clear purpose |
| **Open/Closed** | Commands can be added without modifying existing code |
| **Liskov Substitution** | All commands implement `INavigationCommand` contract |
| **Interface Segregation** | Specialized renderers for different UI components |
| **Dependency Inversion** | Services injected via constructor, not instantiated internally |

### Key Patterns Used

- **Command Pattern** — Decoupled input handling from execution
- **Facade Pattern** — `RepositoryManager` simplifies complex operations
- **Factory Pattern** — `CommandFactory` creates and registers commands
- **State Pattern** — `NavigationState` manages all navigation state
- **Composition Root** — Dependencies wired in main entry point

---

## Troubleshooting

### Command not found after setup

```powershell
. $PROFILE
```

### ExecutionPolicy error

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Config file not found

Run setup again:
```powershell
.\Setup.ps1
```

Or manually create from template:
```powershell
Copy-Item .repo-config.example.json .repo-config.json
notepad .repo-config.json
```

---

## Privacy & Security

This project is designed to **never expose personal information**:

- ✓ Your username is NOT uploaded
- ✓ Your file paths are NOT uploaded  
- ✓ Your aliases are NOT uploaded
- ✓ All personal config files are in `.gitignore`

Only source code and example files are tracked in Git.

---

## Technical Notes

### PowerShell Limitations We Worked Around

- **No true interfaces** — Used abstract base class with throwing methods
- **No private modifiers** — Used `hidden` keyword where possible
- **Limited generics** — Worked with `[hashtable]` and `[ArrayList]`
- **No async/await** — Used Runspace pools for parallel operations
- **Class parsing order** — Careful file loading sequence required

### Performance Considerations

- **Parallel Git loading** — Uses Runspace pool for concurrent status checks
- **Lazy loading** — Git status loaded on demand, not at startup
- **Viewport rendering** — Only visible items are rendered
- **Optimized redraws** — Dirty flags minimize screen updates

---

## Contributing

This is a personal project, but suggestions are welcome. The codebase demonstrates how to build maintainable PowerShell applications — feel free to learn from it or adapt the patterns for your own projects.

---

## Version History

| Version | Description |
|---------|-------------|
| **2.0** | SOLID refactor — Full architectural redesign |
| **1.0** | Original script — Basic navigation and aliases |

---

## Author

**Martin Miguel Bernal Garcia**  
January 2026

---

*Built with PowerShell, engineered with principles.*
