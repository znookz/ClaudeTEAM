---
name: iis-troubleshoot
description: Diagnose an IIS website that is down or returns HTTP 500/502/503 — check site and AppPool state, listening ports, web.config, and the last lines of IIS/event logs. Use when a site on Windows Server/IIS fails, won't start, or shows 5xx errors.
---
# IIS Troubleshoot (read-only)

**กฎ**: อ่านอย่างเดียว · ห้าม `iisreset`/Stop/Restart/Recycle AppPool เอง (เสนอคำสั่งให้ผู้ใช้ยืนยัน) · log อ่านเฉพาะ `-Tail 50` · รายงานสุดท้าย ≤ 15 บรรทัด

## 0. ระบุอาการ
ขอ/ระบุ: ชื่อ site, URL, HTTP status + sub-status (เช่น 500.19, 500.30, 502.5), เวลาที่เริ่มเกิด, มีการ deploy/แก้ config ล่าสุดหรือไม่

## 1. สถานะ Site / AppPool
```powershell
$ErrorActionPreference = "Stop"
Import-Module WebAdministration
Get-Website | Select-Object Name, State, PhysicalPath, @{n='Bindings';e={($_.Bindings.Collection | ForEach-Object bindingInformation) -join ', '}}
Get-ChildItem IIS:\AppPools | Select-Object Name, State, managedRuntimeVersion, @{n='Identity';e={$_.processModel.identityType}}
```
- Pool `Stopped` → มักเกิด Rapid-Fail Protection (503) → ดู Event Log (ขั้น 4) หาสาเหตุก่อน — **ห้าม Start เอง** ให้ผู้ใช้ยืนยัน

## 2. พอร์ตและการเชื่อมต่อ
```powershell
Get-NetTCPConnection -State Listen -LocalPort 80,443 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, OwningProcess
Test-NetConnection -ComputerName localhost -Port 443 -InformationLevel Quiet
Test-NetConnection -ComputerName <db-host> -Port 1433   # PostgreSQL = 5432
Test-NetConnection -ComputerName <backend-host> -Port <app-port>   # กรณี reverse proxy / out-of-process
```
- พอร์ตไม่ listen → binding หาย/site หยุด/พอร์ตชนกับ process อื่น (`Get-Process -Id <OwningProcess>`)

## 3. ตรวจ web.config (อ่านเฉพาะส่วนที่เกี่ยว)
```powershell
$p = "<PhysicalPath>\web.config"
try { [xml]$x = Get-Content $p -Raw; "XML OK" } catch { $_.Exception.Message }   # 500.19 มักมาจาก XML/section ผิด
Select-String -Path $p -Pattern 'aspNetCore|hostingModel|processPath|stdoutLogEnabled|<rewrite|<handlers|httpErrors' | Select-Object -First 20
```
เช็ก: `processPath`/`arguments` ถูกต้อง · `hostingModel` ตรงกับ AppPool (in-process ต้อง *No Managed Code*) · มี `<remove/>` ก่อน `<add/>` ซ้ำ (inheritance) · ติดตั้ง ASP.NET Core Hosting Bundle แล้ว · สิทธิ์ AppPool identity อ่านโฟลเดอร์เว็บได้

## 4. Log (เฉพาะท้ายไฟล์)
```powershell
# HTTP log ล่าสุด — เฉพาะ 5xx (ปรับ W3SVC<id> จาก Get-Website: ID)
$f = Get-ChildItem "C:\inetpub\logs\LogFiles\W3SVC<id>" -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $f.FullName -Tail 50 | Select-String ' (500|502|503) ' | Select-Object -Last 15
# Event Log: แอปพัง/WAS/IIS ใน 2 ชั่วโมง
Get-WinEvent -FilterHashtable @{LogName='Application','System'; Level=1,2; StartTime=(Get-Date).AddHours(-2)} -MaxEvents 15 |
  Select-Object TimeCreated, ProviderName, Id, @{n='Msg';e={$_.Message.Substring(0,[Math]::Min(200,$_.Message.Length))}}
```
ถ้าเปิด stdout log ไว้: `Get-Content <logs\stdout_*.log> -Tail 50` (ห้ามเปิดทั้งไฟล์)

## 5. แปลผล
| อาการ | สาเหตุที่พบบ่อย | ตรวจ |
|---|---|---|
| 500.19 | web.config / section ผิด, module ไม่ติดตั้ง | ขั้น 3, ดู error code ในหน้า error |
| 500.30 / 500.31 | แอป .NET start ไม่ขึ้น (in-process), runtime/Hosting Bundle ไม่ตรง | Event Log + stdout (ชั่วคราว) |
| 500.0 / 500 | exception ในแอป, DB ต่อไม่ได้ | log แอป, `Test-NetConnection` ไป DB |
| 502.5 / 502.3 | out-of-process start ไม่ขึ้น / backend ไม่ตอบ / พอร์ตผิด | ขั้น 2 + `processPath` |
| 503 | AppPool หยุด (Rapid-Fail) / site หยุด / app_offline.htm | ขั้น 1, หาไฟล์ `app_offline.htm` |

## 6. รายงาน (≤ 15 บรรทัด)
`อาการ → สาเหตุที่น่าจะเป็น (พร้อมหลักฐาน 1–2 บรรทัด) → วิธีแก้ที่เสนอ → คำสั่งที่ผู้ใช้ต้องรันเอง (ถ้ามี) + ผลกระทบ`
