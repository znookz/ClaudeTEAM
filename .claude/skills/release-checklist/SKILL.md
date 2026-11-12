---
name: release-checklist
description: Pre-release checklist — build, test, security-auditor review, backup web.config, then propose deploy commands for the user to run. Use before releasing/deploying a web app to IIS. Never deploys by itself.
---
# Release Checklist

**กฎ**: ห้าม deploy/`iisreset`/Restart-*/`git push` เอง · เสนอคำสั่งให้ผู้ใช้รัน · รายงานสุดท้าย ≤ 15 บรรทัด

## 1. Build (เฉพาะโปรเจกต์ที่แก้)
- .NET: `dotnet build <proj>.csproj --no-restore -clp:ErrorsOnly`
- React/Angular: `npm run build` (Angular: `ng build`)
- PHP: `php -l <file>`
- Build พัง → หยุด รายงานสาเหตุ

## 2. Test
- .NET: `dotnet test <proj> --no-build --filter <Name>`
- Node/React: `npm test -- <file>` · `npm run lint`
- Angular: `ng test --watch=false --include=<spec>` · `ng lint`
- ไม่มี test → ระบุในรายงาน ไม่ถือว่าผ่านโดยปริยาย

## 3. Review ตามลำดับ
1. `code-reviewer` (คุณภาพ/diff) → แก้ข้อที่ต้องแก้
2. `security-auditor` (secrets, SQL injection, XSS, IIS hardening) → ต้องไม่มี Critical/High ค้าง

## 4. Backup web.config (ก่อน deploy)
```powershell
$site = "<PhysicalPath>"
Copy-Item "$site\web.config" "$site\web.config.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
```
เสนอให้ผู้ใช้รัน/ยืนยัน · ตรวจ `<compilation debug>`, `httpErrors`, `stdoutLogEnabled` ไม่หลุดค่า Dev ไป Prod

## 5. เสนอคำสั่ง deploy (ผู้ใช้รันเอง)
```powershell
# ตัวอย่าง — ปรับ path/ชื่อ site ก่อนรัน
Copy-Item "<publish-output>\*" "<PhysicalPath>" -Recurse -Force
# ถ้าต้อง recycle (ผู้ใช้ยืนยันเอง): Restart-WebAppPool -Name "<pool>"
```
แนบแผน Rollback: คืน `web.config.*.bak` + โฟลเดอร์ publish รุ่นก่อน

## 6. รายงาน
`Build ✓/✗ · Test ✓/✗/ไม่มี · Review (ผ่าน/ข้อค้าง) · Backup (path) · คำสั่ง deploy ให้ผู้ใช้รัน · Rollback · ความเสี่ยง`
