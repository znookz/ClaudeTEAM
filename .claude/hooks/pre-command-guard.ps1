# PreToolUse guard (matcher: Bash|PowerShell)
# Blocks dangerous commands. exit 2 = block (stderr is fed back to Claude), exit 0 = allow.
# ASCII only on purpose (Windows PowerShell 5.1 reads BOM-less files as ANSI).
$ErrorActionPreference = "Stop"

try {
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $evt = $raw | ConvertFrom-Json
    $cmd = [string]$evt.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
}
catch { exit 0 }   # fail-open if the hook payload cannot be parsed

# --- 1) Always-blocked commands -------------------------------------------------
$blocked = @(
    @{ Name = 'iisreset';          Rx = '(?i)(?<![\w-])iisreset(\.exe)?(?![\w-])' },
    @{ Name = 'Stop-WebAppPool';   Rx = '(?i)(?<![\w-])Stop-WebAppPool(?![\w-])' },
    @{ Name = 'Remove-WebSite';    Rx = '(?i)(?<![\w-])Remove-Web(Site|AppPool|Application|Binding)(?![\w-])' },
    @{ Name = 'appcmd stop/delete'; Rx = '(?i)appcmd(\.exe)?\s+(stop|delete)\s+(site|apppool|app)\b' },
    @{ Name = 'Restart-Computer';  Rx = '(?i)(?<![\w-])(Restart|Stop)-Computer(?![\w-])|(?<![\w-])shutdown(\.exe)?\s+[/-][rsp]\b' },
    @{ Name = 'DROP DATABASE';     Rx = '(?i)\bDROP\s+(DATABASE|SCHEMA)\b' },
    @{ Name = 'DROP TABLE';        Rx = '(?i)\bDROP\s+TABLE\b' },
    @{ Name = 'TRUNCATE TABLE';    Rx = '(?i)\bTRUNCATE\s+TABLE\b' }
)
foreach ($b in $blocked) {
    if ($cmd -match $b.Rx) {
        [Console]::Error.WriteLine("[BLOCKED by pre-command-guard] '$($b.Name)' is forbidden for autonomous execution. Do NOT retry or rephrase. Show the exact command + impact to the user and let them run it themselves.")
        exit 2
    }
}

# --- 2) UPDATE / DELETE without WHERE ------------------------------------------
foreach ($stmt in ($cmd -split ';|(?im)^\s*GO\s*$')) {
    $isDelete = $stmt -match '(?is)\bDELETE\s+FROM\s+[\w\[\]\."`#@]+'
    $isUpdate = $stmt -match '(?is)\bUPDATE\s+[\w\[\]\."`#@]+\s+SET\b'
    if (($isDelete -or $isUpdate) -and ($stmt -notmatch '(?is)\bWHERE\b')) {
        [Console]::Error.WriteLine("[BLOCKED by pre-command-guard] UPDATE/DELETE without WHERE detected. Add a WHERE clause (test it with SELECT first) and provide a rollback plan; or ask the user to run it.")
        exit 2
    }
}

exit 0
