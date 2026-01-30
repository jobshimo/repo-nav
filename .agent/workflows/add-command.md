---
description: How to add a new command to repo-nav
---

# Adding a New Command

## Prerequisites
- Understand the command pattern (see `INavigationCommand.ps1`)
- Know which key will trigger the command

## Steps

### 1. Create the Command File

Create `src/Core/Commands/YourCommand.ps1`:

```powershell
class YourCommand : INavigationCommand {
    [string] GetDescription() {
        return "Your Command Description (KEY)"
    }

    [bool] CanExecute([object]$keyPress, [CommandContext]$context) {
        return $keyPress.VirtualKeyCode -eq [Constants]::KEY_YOUR_KEY
    }

    [void] Execute([object]$keyPress, [CommandContext]$context) {
        $state = $context.State
        
        # Your command logic here
        
        # Always mark for redraw if you change state
        $state.MarkForFullRedraw()
    }
}
```

### 2. Add Key Constant

Edit `src/Config/Constants.ps1`, add to the Keys section:

```powershell
static [int] $KEY_YOUR_KEY = 0xNN  # Replace with actual VK code
```

Common VK codes:
- Letters: A=0x41, B=0x42, ..., Z=0x5A
- Numbers: 0=0x30, 1=0x31, ..., 9=0x39
- F1-F12: 0x70-0x7B

### 3. Register in _index.ps1

Add to `src/Core/Commands/_index.ps1`:

```powershell
. "$commandsPath\YourCommand.ps1"
```

### 4. Add to CommandFactory

Edit `src/Core/Engine/CommandFactory.ps1`, add to the commands array:

```powershell
[YourCommand]::new()
```

### 5. Update Translations (Optional)

If your command has user-facing text, add to:
- `src/Resources/i18n/en.json`
- `src/Resources/i18n/es.json`

## Verification

// turbo
1. Run `.\repo-nav.ps1` to test in development
2. Run `.\Build-Bundle.ps1` to verify bundle builds
3. Test the command works with the assigned key

## Common Patterns

### Access Services
```powershell
$prefs = $context.PreferencesService.LoadPreferences()
$pathManager = $context.PathManager
$renderer = $context.Renderer
```

### Show OptionSelector
```powershell
$config = [SelectionOptions]::new()
$config.Title = "Title"
$config.Options = @(
    @{ DisplayText = "Option 1"; Value = 1 },
    @{ DisplayText = "Option 2"; Value = 2 }
)
$result = $context.OptionSelector.Show($config)
```

### Request Exit State
```powershell
$state.RequestExit([ExitState]::OpenRepository)
$state.RequestExit([ExitState]::Restart)
```
