# PostToolUse verify (matcher: Edit|MultiEdit|Write)
# Syntax/lint check by file extension. exit 2 = failure (stderr is fed back to Claude), exit 0 = OK/skipped.
# Silent on success to save tokens. ASCII only on purpose (Windows PowerShell 5.1).
$ErrorActionPreference = "Stop"
$MaxLines = 12

function Fail([string]$msg) {
    [Console]::Error.WriteLine("[VERIFY FAILED] $msg")
    exit 2
}

function Limit([string]$text, [int]$n = $MaxLines) {
    (($text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Unique | Select-Object -First $n) -join "`n"
}

function Find-Up([string]$dir, [string]$filter, [string]$root) {
    while ($dir) {
        $hit = Get-ChildItem -LiteralPath $dir -Filter $filter -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
        if ($root -and ($dir.TrimEnd('\') -ieq $root.TrimEnd('\'))) { break }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Invoke-Cmd([string]$cmdLine, [string]$cwd, [int]$timeoutSec = 100) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/d /s /c `"$cmdLine`""
    $psi.WorkingDirectory = $cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $o = $p.StandardOutput.ReadToEndAsync()
    $e = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        return @{ Code = 0; Out = "timeout after ${timeoutSec}s (check skipped)"; TimedOut = $true }
    }
    return @{ Code = $p.ExitCode; Out = ($o.Result + "`n" + $e.Result); TimedOut = $false }
}

function Test-Tool([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Test-SqlText([string]$sqlText, [string]$label) {
    $s = [regex]::Replace($sqlText, '(?s)/\*.*?\*/', ' ')
    $s = [regex]::Replace($s, '(?m)--.*$', ' ')
    foreach ($stmt in ($s -split ';|(?im)^\s*GO\s*$')) {
        if ($stmt -match '(?is)\bDROP\s+(DATABASE|SCHEMA)\b')      { Fail "$label : DROP DATABASE/SCHEMA found. Remove it, or ask the user to run it manually with a rollback plan." }
        if ($stmt -match '(?is)\bTRUNCATE\s+TABLE\b')              { Fail "$label : TRUNCATE TABLE found. Remove it, or ask the user to approve with a rollback plan." }
        if ($stmt -match '(?is)\bDROP\s+TABLE\s+(?!#)(?!IF\s+EXISTS\s+#)') { Fail "$label : DROP TABLE (non-temp) found. Needs explicit user approval + rollback plan." }
        $isDelete = $stmt -match '(?is)\bDELETE\s+FROM\s+[\w\[\]\."`#@]+'
        $isUpdate = $stmt -match '(?is)\bUPDATE\s+[\w\[\]\."`#@]+\s+SET\b'
        if (($isDelete -or $isUpdate) -and ($stmt -notmatch '(?is)\bWHERE\b')) {
            $snippet = ($stmt.Trim() -replace '\s+', ' ')
            if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + '...' }
            Fail "$label : UPDATE/DELETE without WHERE -> '$snippet'. Add a WHERE clause."
        }
    }
}

try {
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $evt = $raw | ConvertFrom-Json
    $file = [string]$evt.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($file) -or -not (Test-Path -LiteralPath $file -PathType Leaf)) { exit 0 }
    $file = (Resolve-Path -LiteralPath $file).Path
    if ($file -match '\\(node_modules|bin|obj|dist)\\') { exit 0 }

    $root = $env:CLAUDE_PROJECT_DIR
    if (-not $root) { $root = [string]$evt.cwd }
    $dir  = Split-Path -Parent $file
    $name = [IO.Path]::GetFileName($file).ToLowerInvariant()
    $ext  = [IO.Path]::GetExtension($file).ToLowerInvariant()
    $label = [IO.Path]::GetFileName($file)

    # ---- XML-based: web.config, *.config, *.xml, *.csproj ... ----
    if ($ext -in '.config', '.xml', '.csproj', '.props', '.targets', '.resx') {
        $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        try { $xml = [xml]$text } catch { Fail "$label is not well-formed XML: $($_.Exception.Message)" }
        if ($name -eq 'web.config') {
            if ($text -match '(?i)stdoutLogEnabled\s*=\s*"true"') {
                Fail "$label : stdoutLogEnabled=""true"" must be false on Prod (log files grow until the disk is full). Set it to false unless the user explicitly asks for temporary debugging."
            }
        }
        if ($ext -eq '.csproj' -and (Test-Tool 'dotnet')) { }   # csproj is validated by the build triggered on .cs edits
        exit 0
    }

    # ---- PowerShell ----
    if ($ext -in '.ps1', '.psm1', '.psd1') {
        $tokens = $null; $errs = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errs)
        if ($errs -and $errs.Count -gt 0) {
            $msg = ($errs | Select-Object -First 5 | ForEach-Object { "L$($_.Extent.StartLineNumber):C$($_.Extent.StartColumnNumber) $($_.Message)" }) -join "`n"
            Fail "$label PowerShell parse errors:`n$msg"
        }
        if ($ext -ne '.psd1') {
            $src = Get-Content -LiteralPath $file -Raw -Encoding UTF8
            if ($src -notmatch '(?im)^\s*\$ErrorActionPreference\s*=\s*[''"]Stop[''"]') {
                Fail "$label : missing `$ErrorActionPreference = ""Stop"" (required in every .ps1)."
            }
        }
        exit 0
    }

    # ---- SQL ----
    if ($ext -eq '.sql') {
        Test-SqlText (Get-Content -LiteralPath $file -Raw -Encoding UTF8) $label
        exit 0
    }

    # ---- JSON (only strict-JSON config files; skip tsconfig/eslintrc which allow comments) ----
    if ($name -match '^(package|composer|appsettings(\..+)?|launchsettings)\.json$') {
        try { [void](Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { Fail "$label is not valid JSON: $($_.Exception.Message)" }
        exit 0
    }

    # ---- C# (.NET 8): build the nearest project, errors only ----
    if ($ext -eq '.cs') {
        if (-not (Test-Tool 'dotnet')) { exit 0 }
        $proj = Find-Up $dir '*.csproj' $root
        if (-not $proj) { exit 0 }
        $r = Invoke-Cmd "dotnet build `"$proj`" --no-restore -nologo -v q -clp:ErrorsOnly" (Split-Path -Parent $proj) 110
        if ($r.TimedOut -or $r.Code -eq 0 -or $r.Out -match 'NETSDK1004|NU1101') { exit 0 }   # skip if packages were never restored
        $errs = ($r.Out -split "`r?`n") | Where-Object { $_ -match ': error ' }
        Fail ("dotnet build failed for " + [IO.Path]::GetFileName($proj) + ":`n" + (Limit ($errs -join "`n") 10))
    }

    # ---- PHP ----
    if ($ext -eq '.php') {
        if (-not (Test-Tool 'php')) { exit 0 }
        $r = Invoke-Cmd "php -l `"$file`"" $dir 30
        if ($r.Code -ne 0 -and -not $r.TimedOut) { Fail ("php -l failed:`n" + (Limit $r.Out 6)) }
        exit 0
    }

    # ---- Frontend / Node: eslint (+ tsc --noEmit for TS) ----
    if ($ext -in '.js', '.jsx', '.mjs', '.cjs', '.ts', '.tsx') {
        $pkg = Find-Up $dir 'package.json' $root
        if (-not $pkg) {
            if ($ext -in '.js', '.mjs', '.cjs' -and (Test-Tool 'node')) {
                $r = Invoke-Cmd "node --check `"$file`"" $dir 30
                if ($r.Code -ne 0 -and -not $r.TimedOut) { Fail ("node --check failed:`n" + (Limit $r.Out 6)) }
            }
            exit 0
        }
        $pdir = Split-Path -Parent $pkg
        $bin  = Join-Path $pdir 'node_modules\.bin'

        if (Test-Path (Join-Path $bin 'eslint.cmd')) {
            $r = Invoke-Cmd "`"$bin\eslint.cmd`" --quiet `"$file`"" $pdir 60
            if ($r.Code -eq 1 -and -not $r.TimedOut) { Fail ("eslint errors:`n" + (Limit $r.Out)) }   # code 2 = config problem -> do not block
        }
        elseif ($ext -in '.js', '.mjs', '.cjs' -and (Test-Tool 'node')) {
            $r = Invoke-Cmd "node --check `"$file`"" $dir 30
            if ($r.Code -ne 0 -and -not $r.TimedOut) { Fail ("node --check failed:`n" + (Limit $r.Out 6)) }
        }

        if ($ext -in '.ts', '.tsx' -and (Test-Path (Join-Path $bin 'tsc.cmd'))) {
            $tsconfig = if (Test-Path (Join-Path $pdir 'tsconfig.app.json')) { 'tsconfig.app.json' } elseif (Test-Path (Join-Path $pdir 'tsconfig.json')) { 'tsconfig.json' } else { $null }
            if ($tsconfig) {
                $r = Invoke-Cmd "`"$bin\tsc.cmd`" --noEmit -p $tsconfig" $pdir 100
                if ($r.Code -ne 0 -and -not $r.TimedOut) {
                    $errs = ($r.Out -split "`r?`n") | Where-Object { $_ -match 'error TS' }
                    Fail ("tsc type errors:`n" + (Limit ($errs -join "`n") 10))
                }
            }
        }
        exit 0
    }

    exit 0
}
catch {
    [Console]::Error.WriteLine("[post-edit-verify] hook internal error (non-blocking): $($_.Exception.Message)")
    exit 1
}
