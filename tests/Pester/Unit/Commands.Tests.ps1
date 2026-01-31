Describe "Complex Commands" {
    BeforeAll {
        $scriptRoot = Resolve-Path "$PSScriptRoot\..\..\.."
        $srcRoot = Join-Path $scriptRoot "src"
        
        # 1. Config
        . "$srcRoot\Config\_index.ps1"
        [Constants]::Initialize($scriptRoot)

        # 2. Models
        . "$srcRoot\Models\_index.ps1"

        # 3. Core Infrastructure & Services
        . "$srcRoot\Core\Interfaces\IProgressReporter.ps1"
        . "$srcRoot\Core\Interfaces\IRepositoryManager.ps1"
        . "$srcRoot\Startup\ServiceRegistry.ps1"
        if (-not ([System.Management.Automation.PSTypeName]'NavigationState').Type) {
            . "$srcRoot\Core\State\NavigationState.ps1"
        }
        . "$srcRoot\Services\_index.ps1"
        
        # 4. UI
        . "$srcRoot\UI\_index.ps1"

        # 5. Core Managers
        . "$srcRoot\Core\Services\PathManager.ps1"
        . "$srcRoot\Core\Services\GitStatusManager.ps1"
        . "$srcRoot\Core\Services\RepositorySorter.ps1"
        . "$srcRoot\Core\RepositoryManager.ps1"

        # 6. State
        if (-not ([System.Management.Automation.PSTypeName]'CommandContext').Type) {
            . "$srcRoot\Core\State\CommandContext.ps1"
        }

        # 7. Commands
        if (-not ([System.Management.Automation.PSTypeName]'INavigationCommand').Type) {
            . "$srcRoot\Core\Commands\INavigationCommand.ps1"
        }
        . "$srcRoot\Core\Commands\NpmCommand.ps1"

        # Load Mocks
        . "$scriptRoot\tests\Mocks\MockRepositoryManager.ps1"
    }

    Context "NpmCommand" {
        BeforeAll {
            Mock Start-Process { 
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            Mock Start-Job {
               # Use the real cmdlet to avoid recursion and satisfy type requirements
               $realCmd = Get-Command Start-Job -CommandType Cmdlet
               $j = & $realCmd -ScriptBlock { return $true }
               $j | Wait-Job | Out-Null
               return $j
            }
            Mock Receive-Job { return $true }
            Mock Remove-Job { param([object]$Job, [object]$Force, [object]$ErrorAction) }
            Mock Wait-Job { }
            Mock Start-Sleep { }
            Mock Write-Host { } 
            Mock Push-Location { }
            Mock Pop-Location { }
            Mock Test-Path { return $true }        }

        It "Execute (Key I) runs invoke install" {
            # Setup Context
            $mockConsole = [ConsoleHelper]::new()
            # Silence Console
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "ClearForWorkflow" -Value {} -Force
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "WriteLineColored" -Value { param($m, $c) } -Force
            
            # Setup State
            $mockState = [NavigationState]::new(@())
            $repo = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\FakeRepo"))
            $mockState.SetRepositories(@($repo))
            $mockState.SetCurrentIndex(0)
            # Mock Stop/Resume
            $mockState | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {} -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "Resume" -Value {} -Force
            
            # Setup Renderer
            $mockColor = [ColorSelector]::new($null, $null, $null)
            $renderer = [UIRenderer]::new($mockConsole, $null)
            $renderer | Add-Member -MemberType ScriptMethod -Name "RenderWorkflowHeader" -Value { param($t, $r) } -Force
            
            # Setup RepoManager (Wrapper for NpmService)
            # We mock the NpmService property directly on a dummy object 
            # OR we can instantiate Repomanager and mock property? No, RepoManager logic is heavy.
            # Since CommandContext.RepoManager is type [RepositoryManager] (if strongly typed in Context), we might need real instance.
            # Let's check CommandContext line: [RepositoryManager] $RepoManager.
            # Yes it is typed. So we must provide [RepositoryManager].
            # Instantiate real RepositoryManager? It needs State, GitService, etc. Logic heavy.
            # Hack: Create a stub class in memory that inherits/mocks it? Or use uninitialized object trick?
            # [RepositoryManager] can be instantiated with nulls?
            # Constructor: RepositoryManager($state, $gitService, $parallelLoader, $statusManager, $npmService, $configService)
            # We can pass $nulls to constructor in PS? Yes usually.
            
            # Create Services for RepoManager (Typed)
            $configSrv = [ConfigurationService]::new()
            $prefSrv = [UserPreferencesService]::new()
            $gitSrv = [GitService]::new()
            $gitReadSrv = [GitReadService]::new()
            $gitWriteSrv = [GitWriteService]::new()
            $npmSrv = [NpmService]::new()
            [ServiceRegistry]::Register('NpmService', $npmSrv)
            $aliasMgr = [AliasManager]::new($configSrv)
            $favSrv = [FavoriteService]::new($configSrv)
            $parallelSrv = [ParallelGitLoader]::new()
            $repoOpsSrv = [RepositoryOperationsService]::new($gitSrv)
            $gitStatMgr = [GitStatusManager]::new($gitSrv, $parallelSrv, $prefSrv, $null)
            $sorter = [RepositorySorter]::new()
            $hiddenSrv = [HiddenReposService]::new($prefSrv)

            # Use MockRepositoryManager (SOLID)
            $repoManager = [MockRepositoryManager]::new()
            $repoManager.Repositories = @($repo)
            $repoManager.RepositoryToReturn = $repo

            $context = [CommandContext]::new()
            $context.Console = [ConsoleHelper]$mockConsole
            $context.State = $mockState
            $context.Renderer = $renderer
            $context.RepoManager = $repoManager
            $context.LocalizationService = $null # Optional in View

            $cmd = [NpmCommand]::new()
            
            # Key "I"
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_I }
            
            $cmd.Execute($keyPress, $context)
            
            # Assertions handled by Mocks not throwing and completing
            # We can assert Mock Start-Process called
            Assert-MockCalled Start-Process -Times 1
        }

        It "Execute (Key X) runs invoke remove (Delete)" {
             # Context setup similar to above execution
             # We can copy paste or refactor. Copy paste for safety here.
            $mockConsole = [ConsoleHelper]::new()
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "ClearForWorkflow" -Value {} -Force
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "WriteLineColored" -Value { param($m, $c) } -Force
            # ConfirmAction mock -> return True
            $mockConsole | Add-Member -MemberType ScriptMethod -Name "ConfirmAction" -Value { return $true } -Force

            $mockState = [NavigationState]::new(@())
            $repo = [RepositoryModel]::new([System.IO.DirectoryInfo]::new("C:\FakeRepo"))
            $mockState.SetRepositories(@($repo))
            $mockState.SetCurrentIndex(0)
            $mockState | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {} -Force
            $mockState | Add-Member -MemberType ScriptMethod -Name "Resume" -Value {} -Force

            $mockColor = [ColorSelector]::new($null, $null, $null)
            $renderer = [UIRenderer]::new($mockConsole, $null)
            $renderer | Add-Member -MemberType ScriptMethod -Name "RenderWorkflowHeader" -Value { param($t, $r) } -Force
            # Mock RenderError
            $renderer | Add-Member -MemberType ScriptMethod -Name "RenderError" -Value { param($m) } -Force

            # Create Services for RepoManager (Typed)
            $configSrv = [ConfigurationService]::new()
            $prefSrv = [UserPreferencesService]::new()
            $gitSrv = [GitService]::new()
            $gitReadSrv = [GitReadService]::new()
            $gitWriteSrv = [GitWriteService]::new()
            $npmSrv = [NpmService]::new()
            $aliasMgr = [AliasManager]::new($configSrv)
            $favSrv = [FavoriteService]::new($configSrv)
            $parallelSrv = [ParallelGitLoader]::new()
            $repoOpsSrv = [RepositoryOperationsService]::new($gitSrv)
            $gitStatMgr = [GitStatusManager]::new($gitSrv, $parallelSrv, $prefSrv, $null)
            $sorter = [RepositorySorter]::new()
            $hiddenSrv = [HiddenReposService]::new($prefSrv)

            # Use MockRepositoryManager (SOLID)
            $repoManager = [MockRepositoryManager]::new()
            $repoManager.Repositories = @($repo)
            $repoManager.RepositoryToReturn = $repo

            $context = [CommandContext]::new()
            $context.Console = [ConsoleHelper]$mockConsole
            $context.State = $mockState
            $context.Renderer = $renderer
            $context.RepoManager = $repoManager

            $cmd = [NpmCommand]::new()
            
            # Key "X"
            $keyPress = [PSCustomObject]@{ VirtualKeyCode = [Constants]::KEY_X }
            
            $cmd.Execute($keyPress, $context)
            
            Assert-MockCalled Start-Job -Times 1
        }
    }
}
