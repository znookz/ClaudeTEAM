---
paths:
  - "**/web.config"
  - "**/*.config"
  - "**/*.{ps1,psm1,psd1}"
  - "**/infra/**"
  - "**/deploy/**"
  - "**/app_offline.htm"
---
# Windows Server / IIS / Network Rules

## web.config
- **Config Inheritance**: ค่าถูกสืบทอดจาก `applicationHost.config` และ `web.config` ของโฟลเดอร์แม่/เว็บแม่ → ใช้ `<remove/>`/`<clear/>` ก่อน `<add/>` ที่ซ้ำ, ใช้ `<location path="." inheritInChildApplications="false">` กัน child app รับค่าไปโดยไม่ตั้งใจ
- ก่อนแก้: backup (`Copy-Item web.config "web.config.bak-$(Get-Date -f yyyyMMdd-HHmm)"`) · หลังแก้: ตรวจ XML ผ่าน (hook ทำให้) · **อย่าให้ไฟล์ .bak ขึ้น deploy**
- **`hostingModel`** (ASP.NET Core): `inprocess` (ค่าเริ่มต้น, เร็ว, AppPool = *No Managed Code*, 1 pool ต่อ 1 in-process app) หรือ `outofprocess` (Kestrel + reverse proxy) — ห้ามเปลี่ยนโดยไม่แจ้ง และห้ามผสม in-process หลายแอปใน AppPool เดียวกัน
- **ปิด `stdoutLogEnabled` บน Prod** (`stdoutLogEnabled="false"`) — เปิดได้ชั่วคราวเพื่อดีบักเท่านั้น (ต้องมีสิทธิ์เขียนโฟลเดอร์ log และต้องปิดคืน เพราะไฟล์โตจนดิสก์เต็ม)
- ห้ามใส่ connection string/รหัสผ่านแบบ plain text ใน `web.config` (ใช้ env var / secret store / `aspnet_regiis` เข้ารหัส)
- ตรวจ `requestLimits` (maxAllowedContentLength), `httpErrors existingResponse="PassThrough"` (ไม่ให้ IIS กลืน error JSON ของ API), `rewrite` rules ไม่วนลูป

## Deploy / File Locking
- DLL/ไฟล์ถูกล็อกโดย `w3wp.exe` — ใช้ `app_offline.htm` วางในโฟลเดอร์เว็บเพื่อปล่อยล็อก แล้วลบหลัง deploy เสร็จ (ต้องแจ้งผู้ใช้ก่อน เพราะเว็บจะ 503 ช่วงนั้น)
- **ห้ามหยุด/รีไซเคิล AppPool หรือ `iisreset` เอง** — เสนอคำสั่งให้ผู้ใช้ยืนยัน
- คัดลอกด้วย `robocopy <src> <dst> /MIR /R:3 /W:5 /XF web.config *.bak *.log` (ระวัง `/MIR` ลบไฟล์ปลายทาง → ทดสอบด้วย `/L` ก่อน) · ห้ามทับ `web.config` ของ Prod ด้วยของ Dev
- สิทธิ์: AppPool identity ต้องมีสิทธิ์ Read ที่โฟลเดอร์เว็บ และ Modify เฉพาะโฟลเดอร์ที่ต้องเขียน (logs/uploads) เท่านั้น

## Network
- เช็กพอร์ตด้วย `Test-NetConnection -ComputerName <host> -Port <port>` (ใช้ `-InformationLevel Quiet` เมื่อต้องการ true/false) — ห้ามเดาว่าพอร์ตเปิด
- พอร์ตที่พบบ่อย: 80/443 (IIS), 1433 (MSSQL), 5432 (PostgreSQL), 3389 (RDP), 5985/5986 (WinRM)
- ดู listener: `Get-NetTCPConnection -State Listen -LocalPort <port>` · Firewall: `Get-NetFirewallRule -DisplayName <name>` (แก้กฎ Firewall ต้องขออนุมัติ)
- เครือข่ายภายใน: ใช้ชื่อ DNS/FQDN แทน IP ตายตัว · TLS cert ต้องตรวจวันหมดอายุ (`Get-ChildItem Cert:\LocalMachine\My`) และห้ามแสดง/ส่งออก private key

## PowerShell (`.ps1`)
- บรรทัดแรกของโค้ดต้องมี **`$ErrorActionPreference = "Stop"`** เสมอ (hook ตรวจให้) · แนะนำเพิ่ม `Set-StrictMode -Version Latest`
- คำสั่งที่เปลี่ยนระบบ (`Remove-*`, `Set-*`, `Stop-*`) รองรับ `-WhatIf` และ `[CmdletBinding(SupportsShouldProcess)]`
- ห้ามฝังรหัสผ่านใน script (ใช้ `Get-Credential`/SecretManagement) · ห้าม `Invoke-Expression` กับ input ภายนอก
- ไฟล์ `.ps1` ใช้ encoding UTF-8 with BOM ถ้ามีภาษาไทย (Windows PowerShell 5.1) · log ใช้ `Start-Transcript`/`Write-Verbose` แทน `Write-Host` ยาวๆ
- อ่าน log: `Get-Content <file> -Tail 50` เท่านั้น
