---
name: onboard-repo
description: สร้าง (หรือ merge) CLAUDE.md ให้ repo ใหม่ โดยตรวจ stack ด้วย Glob และอ่านเฉพาะไฟล์สำคัญ เรียกด้วย "/onboard-repo <path ของ repo>" ใช้เมื่อ repo เป้าหมายยังไม่มี CLAUDE.md หรือผู้ใช้ขอ onboard repo
---
# Onboard Repo (ตรวจ stack → เขียน CLAUDE.md ≤ 60 บรรทัด)

**Input**: `<path ของ repo>` (ถ้าไม่ระบุ ถามผู้ใช้ 1 ข้อ)

**กฎเหล็ก**: ห้ามอ่าน `.env`, `*.pfx`, `*.key` · `appsettings*.json`/`web.config` ดูเฉพาะ **key/ชื่อ section** ห้ามเอาค่า connection string/secret/token (mask `***`) · ห้ามอ่านทั้งโฟลเดอร์ · ไม่เดา ถ้าไม่แน่ใจใส่ `TODO: ยืนยัน` · ตอบกลับสรุป ≤ 10 บรรทัด

## ขั้นตอน
1. **ตรวจ stack (Glob เท่านั้น)** ใน `<repo>`: `**/*.sln`, `**/*.csproj`, `**/package.json` (ไม่รวม node_modules), `angular.json`, `**/composer.json`, `**/*.sql`, `**/web.config`, `**/*.ps1`
2. **Read เฉพาะช่วงสำคัญ** (`offset`/`limit`): `*.csproj` (TargetFramework, PackageReference หลัก/ORM), `package.json` (`scripts`, deps หลัก+เวอร์ชัน), `Program.cs`/`Startup.cs` (DI, middleware, auth, ส่วนต้นไฟล์), `appsettings*.json` (key เท่านั้น), `web.config` (handler/rewrite/key เท่านั้น), โครงสร้างโฟลเดอร์ระดับบน (Glob `*/` ชั้นเดียว)
3. **หา convention จริง**: ใช้ Grep เล็กๆ (เช่น `class .*Controller`, `interface I.*Service`, `catch`/ExceptionMiddleware) ดูตัวอย่าง 1–2 ไฟล์ ไม่อ่านทั้งโปรเจกต์
4. **เขียน `<repo>\CLAUDE.md` ≤ 60 บรรทัด** ตาม template ด้านล่าง
5. **ถ้ามี CLAUDE.md อยู่แล้ว → merge ห้ามเขียนทับ**: Read ก่อน, คงของเดิมทั้งหมด, เติมเฉพาะหัวข้อ/บรรทัดที่ขาด (Edit แบบ minimal diff), ขัดแย้งให้ใส่ `TODO: ยืนยัน` ไม่ลบของเดิม
6. **รายงาน ≤ 10 บรรทัด**: stack ที่พบ / ไฟล์ที่สร้าง-แก้ / หัวข้อที่เป็น TODO / ข้อควรระวังที่พบ

## Template
```markdown
# <ชื่อ repo>
## Overview
<1–2 บรรทัด: ระบบทำอะไร, ผู้ใช้หลัก>
## Stack
<เช่น .NET 8 Web API · EF Core 8 · MS SQL · React 18 · IIS>
## โครงสร้างโฟลเดอร์
- `src/Api` — controllers/endpoints
- `src/BusinessLogic` — services
## Build / Test / Run
- Build: `<คำสั่งจริง>` · Test: `<คำสั่งจริง>` · Run: `<คำสั่งจริง>`
## Conventions
- Naming: ... · Layering: Controller → Service → Repository · Error handling: ...
## DB
- DB: `<ชื่อ>` · ORM: `<EF/Dapper/ADO>` · ตารางหลัก: `<t1, t2>` (ห้ามใส่ connection string)
## Deploy / IIS
- Site/AppPool: <TODO: ยืนยัน> · web.config: backup ก่อนแก้
## Gotchas
- <สิ่งที่พลาดบ่อย>
## Do-not-touch
- <ไฟล์/โฟลเดอร์ generated, Migrations เก่า, config Production>
```
