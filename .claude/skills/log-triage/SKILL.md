---
name: log-triage
description: Triage IIS and application logs safely — read only the tail with Get-Content -Tail and filter with Select-String, never open a whole log, mask secrets. Use when investigating errors, slow requests, or 5xx from log files.
---
# Log Triage (read-only)

**กฎ**: ห้ามเปิดทั้งไฟล์ (ใช้ `-Tail` เสมอ) · กรองด้วย `Select-String` · mask password/token/connection string เป็น `***` · รายงาน ≤ 15 บรรทัด
หมายเหตุ: settings deny การ `Read` ไฟล์ `*.log` → ใช้ PowerShell `Get-Content -Tail` เท่านั้น

## IIS log
```powershell
$f = Get-ChildItem "C:\inetpub\logs\LogFiles\W3SVC<id>" -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $f.FullName -Tail 200 | Select-String ' (500|502|503|504) ' | Select-Object -Last 20
# ช้า: time-taken (คอลัมน์ท้าย) — ดู header #Fields: ก่อน
Get-Content $f.FullName -TotalCount 5 | Select-String '#Fields'
```

## App log / stdout
```powershell
$l = Get-ChildItem "<logdir>" -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $l.FullName -Tail 50
Get-Content $l.FullName -Tail 500 | Select-String -Pattern 'ERROR|Exception|Timeout|Deadlock' -Context 0,2 | Select-Object -Last 15
```

## Event Log
```powershell
Get-WinEvent -FilterHashtable @{LogName='Application','System'; Level=1,2; StartTime=(Get-Date).AddHours(-2)} -MaxEvents 15 |
  Select-Object TimeCreated, ProviderName, Id, @{n='Msg';e={$_.Message.Substring(0,[Math]::Min(200,$_.Message.Length))}}
```

## ขั้นตอน
1. ระบุช่วงเวลา/ไฟล์ล่าสุด → `-Tail` เล็กก่อน (50) ขยายทีละน้อย (≤ 500)
2. กรอง pattern → จัดกลุ่มข้อผิดพลาดเดียวกัน นับจำนวน
3. mask ค่าลับก่อนรายงาน (`Password=***`, `Bearer ***`)
4. ต้องวิเคราะห์ลึก → ส่งต่อ `win-infra-iis` (infra) หรือ `backend-dba` (SQL/โค้ด)

## รายงาน
`ช่วงเวลา · error ที่พบบ่อย (จำนวน) · ตัวอย่าง 1–2 บรรทัด (mask แล้ว) · สาเหตุที่น่าจะเป็น · ขั้นต่อไป`
