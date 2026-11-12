$ErrorActionPreference = "Stop"
try {
    $root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $f = Join-Path $root ".claude\memory\lessons.md"
    if (Test-Path -LiteralPath $f) {
        Write-Output "## Lessons (.claude/memory/lessons.md)"
        Get-Content -LiteralPath $f -Encoding UTF8
    }
} catch {
    # ไม่ให้ session เริ่มไม่ได้เพราะอ่าน lessons ไม่สำเร็จ
}
exit 0
