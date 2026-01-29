
class FlowControllerBase {
    [CommandContext] $Context
    [object] $Repo
    [GitService] $GitService
    [GitReadService] $GitReadService
    [GitWriteService] $GitWriteService

    FlowControllerBase([CommandContext]$context, [object]$repo) {
        $this.Context = $context
        $this.Repo = $repo
        $this.GitService = $context.RepoManager.GitService
        $this.GitReadService = $context.RepoManager.GitReadService
        $this.GitWriteService = $context.RepoManager.GitWriteService
    }
    
    hidden [void] ShowMessage([string]$message, [ConsoleColor]$color) {
        $this.Context.Console.WriteColored("  $message", $color)
    }
    
    hidden [void] ShowError([string]$message) {
        $this.Context.Console.WriteLineColored("  [!] $message", [Constants]::ColorError)
        $this.Context.Console.ReadKey()
    }
}
