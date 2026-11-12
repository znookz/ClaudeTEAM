---
name: api-contract-sync
description: Keep API contract in sync across layers — update contracts/openapi first, then backend, then frontend types, in that order. Use when an endpoint/DTO changes and frontend types must follow.
---
# API Contract Sync

**กฎ**: ทำเป็น **ลำดับ** (ไม่ขนาน) · เคารพ Module Ownership: `contracts/**`,`openapi.*` = `backend-dba`; `frontend-specialist` ขอแก้ผ่าน lead

## ลำดับ
1. **Contract** (`contracts/**`, `openapi.*`) — `backend-dba` แก้ก่อน: path, method, request/response schema, status code, nullable/required
2. **Backend** (DTO/controller/validation) — `backend-dba` ทำให้ตรง contract · build: `dotnet build <proj>.csproj --no-restore -clp:ErrorsOnly`
3. **Frontend types/API client** — `frontend-specialist` อัปเดต type/interface/service ตาม contract ที่ได้ (ส่งผลขั้น 1 ใน prompt) · build: `npm run build` / `ng build`
4. Review: `code-reviewer` → `security-auditor` (ถ้าแตะ auth/input)

## ตรวจ
```powershell
Select-String -Path contracts\*,openapi.* -Pattern '<endpoint|schemaName>'
```
- ชื่อ field/case (camelCase vs PascalCase), nullable, enum, date format ตรงกันทั้ง 3 ชั้น
- Breaking change (ลบ/เปลี่ยนชนิด field) → แจ้งผู้ใช้ก่อน และพิจารณา version endpoint ใหม่
- ห้าม frontend แก้ contract เอง

## รายงาน (≤ 10 บรรทัด)
`ไฟล์ที่แก้แต่ละชั้น · breaking change? · ผล build ทั้ง BE/FE · ความเสี่ยง`
