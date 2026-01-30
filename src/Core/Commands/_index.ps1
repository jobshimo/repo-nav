# ============================================================================
# Commands Layer Index
# ============================================================================
# Dependencies: CommandContext (loaded before this index)
# NOTE: GitFlowCommand is in Flows layer, not here
# ============================================================================

$commandsPath = $PSScriptRoot

# Interface first
. "$commandsPath\INavigationCommand.ps1"

# Command implementations
. "$commandsPath\ExitCommand.ps1"
. "$commandsPath\NavigationCommand.ps1"
. "$commandsPath\RepositoryCommand.ps1"
. "$commandsPath\GitCommand.ps1"
. "$commandsPath\FavoriteCommand.ps1"
. "$commandsPath\AliasCommand.ps1"
. "$commandsPath\NpmCommand.ps1"
. "$commandsPath\RepositoryManagementCommand.ps1"
. "$commandsPath\PreferencesCommand.ps1"
. "$commandsPath\CreateFolderCommand.ps1"
. "$commandsPath\SearchCommand.ps1"
. "$commandsPath\HideRepoCommand.ps1"
. "$commandsPath\ToggleHiddenVisibilityCommand.ps1"
. "$commandsPath\SwitchPathCommand.ps1"
