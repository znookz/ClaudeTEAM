 # CLAUDE.md — Full-Stack Web / Windows Server / IIS
ตอบภาษาไทย สั้นกระชับ (โค้ด/คำสั่ง/ชื่อไฟล์ใช้อังกฤษ) · กฎเชิงลึกอยู่ใน `.claude/rules/` (โหลดตาม path) และ `.claude/skills/` (เรียกเมื่อจำเป็น)

## Tech Stack
- Frontend: React, Angular | Backend: C# .NET 8, Node.js, PHP
- Database: MS SQL Server, PostgreSQL
- Infra: Windows Server, IIS (reverse proxy), PowerShell, Internal Network

## Build / Test (รันเฉพาะโปรเจกต์ที่แก้ ไม่รันทั้ง solution ถ้าไม่จำเป็น)
| Stack | Build | Test / Lint |
|---|---|---|
| .NET 8 | `dotnet build <proj>.csproj --no-restore -clp:ErrorsOnly` | `dotnet test <proj> --no-build --filter <Name>` |
| React/Node | `npm run build` | `npm test -- <file>` · `npm run lint` |
| Angular | `npm run build` (`ng build`) | `ng test --watch=false --include=<spec>` · `ng lint` |
| PHP | `php -l <file>` | `vendor/bin/phpunit --filter <Name>` |
| PowerShell | — | `Invoke-ScriptAnalyzer <file>` (hook ตรวจ Parser ให้อัตโนมัติ) |

## กฎเหล็กประหยัด Token
1. **Concise**: ตอบสั้น ตรงประเด็น ไม่ทวนคำถาม ไม่สรุปซ้ำสิ่งที่ diff แสดงอยู่แล้ว
2. **ห้ามอ่านทั้งโฟลเดอร์/ทั้งไฟล์ใหญ่**: ใช้ `Glob`/`Grep` หาก่อน แล้ว `Read` เฉพาะช่วง (`offset`/`limit`)
3. **Log**: อ่านด้วย `Get-Content <f> -Tail 50` + `Select-String` เท่านั้น ห้ามเปิดทั้งไฟล์
4. **Minimal Diffs**: แก้เฉพาะจุดที่จำเป็น ไม่ reformat ไม่ rename ไม่ refactor นอกขอบเขต
5. **โยนงานหนักให้ Sub-agents** (ค้นหาวงกว้าง, อ่านหลายไฟล์, วิเคราะห์ log/SQL, audit) และสั่งให้ตอบกลับ ≤ 10 บรรทัด
6. ไม่ต้อง Read ซ้ำไฟล์ที่เพิ่งแก้ · ไม่ต้องรัน build/test เต็มชุดหลังแก้ทุกครั้ง (hook ตรวจ syntax ให้แล้ว)
7. ถ้าไม่แน่ใจ ถามสั้นๆ ข้อเดียว ดีกว่าเดาแล้วแก้ผิดหลายรอบ
8. **Commit text**: ทุกครั้งที่ทำงานเสร็จ ปิดท้ายด้วยข้อความ commit สั้นๆ 1 บรรทัด (รูปแบบ `type: สรุปสั้น`) ให้ผู้ใช้คัดลอก ห้ามรัน git commit/push เอง

## Safety Guardrails (ห้ามฝ่าฝืน — ต้องให้ผู้ใช้ยืนยันก่อนทุกครั้ง)
- ห้ามรันเอง: `iisreset`, `Stop-WebAppPool`, `Restart-WebAppPool`, `Restart-Service`, `Remove-WebSite`, `Restart-Computer` → เสนอคำสั่งให้ผู้ใช้รันเอง
- ห้าม `DROP`, `TRUNCATE`, และ `UPDATE`/`DELETE` ที่ไม่มี `WHERE` · ทุก DML/DDL ต้องมีแผน Rollback และทดสอบบน Dev/UAT ก่อน
- ห้ามแสดงรหัสผ่าน/Connection String/Token/Private key ในแชท (mask เป็น `***`) · ห้ามอ่าน `.env`, `*.pfx`, `*.key`
- ห้าม `git push`, deploy, หรือแก้ config บน Production โดยพลการ · แก้ `web.config` ต้อง backup ก่อน
- Hooks ใน `.claude/hooks/` บล็อกคำสั่งอันตรายและตรวจ syntax อัตโนมัติ — ห้ามแก้/ปิด hook เพื่อเลี่ยงการบล็อก

## Module Ownership (โหมด Agent Teams — 1 ไฟล์ = 1 เจ้าของ ห้ามแก้ข้ามเขต)
| เขต (path) | เจ้าของ | ผู้อื่นทำได้ |
|---|---|---|
| `src/frontend/**`, `*.tsx`, `*.component.ts`, `*.html`, `*.scss` | `frontend-specialist` | อ่านอย่างเดียว |
| `src/api/**`, `server/**`, `*.cs`, `*.php`, `*.sql`, `db/**`, `**/Migrations/**` | `backend-dba` | อ่านอย่างเดียว |
| `contracts/**`, `openapi.*` (API contract) | `backend-dba` | `frontend-specialist` ขอแก้ผ่าน lead |
| `infra/**`, `deploy/**`, `*.ps1`, `web.config`, `applicationHost.config` | `win-infra-iis` | อ่านอย่างเดียว |
| `*.test.*`, `*.spec.*`, `*Tests*/**` | `test-writer` (เฉพาะไฟล์ test ไม่แก้ source) | อ่านอย่างเดียว |
| ทั้ง repo | `code-reviewer` | **Read-only** (review ก่อน security-auditor) |
| ทั้ง repo | `security-auditor` | **Read-only** (รายงานเท่านั้น ไม่แก้) |
| `CLAUDE.md`, `.claude/**` | lead (เธรดหลัก) เท่านั้น | ห้ามแก้ |

โปรเจกต์ที่กำลังแก้: leader อ่าน `.claude/memory/projects.md` ตอนเริ่มงาน (ลบแถวเมื่องานเสร็จ)

กติกาทีม: (1) ต้องแก้ไฟล์นอกเขต → ส่งข้อความหาเจ้าของ/lead พร้อมระบุไฟล์+สิ่งที่ต้องแก้ ห้ามแก้เอง
(2) แตกงานตามเขตไฟล์ ไม่ให้สอง agent แตะไฟล์เดียวกัน (3) ปิดงานด้วยสรุป: ไฟล์ที่แก้ / ผลทดสอบ / ความเสี่ยง
