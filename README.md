# Repository Navigator

Interactive PowerShell tool for managing multiple Git repositories with aliases, npm operations, and Git status tracking.

---

## Features

- Navigate repositories with arrow keys
- Set aliases with custom colors for quick identification
- Manage npm dependencies (install/remove node_modules)
- Git operations (clone, status tracking, branch info)
- Delete repositories with safety checks
- Smart sorting (favorites first, then alphabetical)

---

## Installation

**1. Clone or download this repository**

```powershell
git clone https://github.com/jobshimo/repo-nav.git
cd repo-nav
```

**2. Run the installer**

```powershell
.\Install.ps1
```

**3. Follow the prompts**

The installer will:
- Ask for your repositories path
- Ask for a command name (default: `list`)
- Create `.repo-config.json` with your configuration
- Update your PowerShell profile

**4. Reload your profile**

```powershell
. $PROFILE
```

**5. Launch the navigator**

```powershell
list
```

---

## Controls

| Key | Action | Description |
|-----|--------|-------------|
| Up/Down | Navigate | Move between repositories |
| Enter | Open | Navigate to selected repository |
| E | Set Alias | Create/edit repository alias |
| R | Remove Alias | Remove repository alias |
| I | Install | Run `npm install` |
| X | Remove | Delete `node_modules` folder |
| C | Clone | Clone new repository from URL |
| Del | Delete | Delete repository (with confirmations) |
| L | Load Status | Load Git status for current repo |
| G | Load All | Load Git status for all repos |
| Q / Esc | Quit | Exit navigator |

---

## Configuration

### Config File

The `.repo-config.json` file stores your personal configuration:

```json
{
  "reposBasePath": "C:\\Users\\YourUser\\repos",
  "userName": "YourUser"
}
```

This file is in `.gitignore` and will not be uploaded to the repository.

### Aliases File

The `.repo-aliases.json` file stores your repository aliases:

```json
{
  "my-repo-name": {
    "alias": "SHORT",
    "color": "Green",
    "isFavorite": true
  }
}
```

### Available Colors

Yellow, Green, Cyan, Magenta, Blue, Red, DarkYellow, DarkGreen, DarkCyan, DarkMagenta, DarkBlue, DarkRed, White, Gray

---

## Project Structure

```
repo-nav/
 repo-nav.ps1          # Main entry point
 Install.ps1           # Installation script
 README.md             # This file
 .gitignore            # Git ignore rules
 .repo-config.json     # Your config (gitignored)
 .repo-config.example.json # Config template
 src/
     Config/           # Configuration
     Models/           # Data models
     Services/         # Business logic
     UI/               # User interface
     Core/             # Application core
```

---

## Architecture

Built using **SOLID principles**:

- **Single Responsibility**: Each class has one clear purpose
- **Open/Closed**: Easy to extend without modifying existing code
- **Dependency Injection**: Dependencies injected through constructors
- **Facade Pattern**: High-level operations through RepositoryManager
- **Separation of Concerns**: Models, Services, UI, and Core layers

---

## Troubleshooting

### Command not found

```powershell
. $PROFILE
```

### ExecutionPolicy error

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Config file not found

Run the installer or copy the example:

```powershell
Copy-Item .repo-config.example.json .repo-config.json
notepad .repo-config.json
```

---

## Security & Privacy

This project is designed to NOT expose personal information:

- Your username is NOT uploaded to the repository
- Your project paths are NOT uploaded to the repository
- Your personal aliases are NOT uploaded to the repository
- All personal configuration is in `.gitignore`

Only source code and example files are uploaded.

---

## Project Info

**Version:** 2.0 (SOLID Refactored)
**Author:** Martin Miguel Bernal Garcia
**Date:** January 2026
**License:** Internal use

---

Made with PowerShell
