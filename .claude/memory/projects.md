# โปรเจกต์ที่กำลังแก้ (ชั่วคราว)
> ลบแถวเมื่องานเสร็จ · leader อ่านไฟล์นี้ตอนเริ่มงาน

| path | stack | build | test | สถานะ |
|---|---|---|---|---|
| `C:\Work\Dev\DOHOME\WPT.DOHOME.REPORT.API` | .NET (`WMS.Report.Solution.sln`; หลัก `Report.API`, `Report.Business`, `*.DataAccess`) | `dotnet build Report.API\Report.API.csproj --no-restore -clp:ErrorsOnly` | ยังไม่พบ test project (ไม่ได้ตรวจ csproj อื่นเพิ่ม) | กำลังแก้ |
| `C:\Work\Dev\DOHOME\WEB-WPT` | React 18 + Vite (`wms-fulfillment`) | `npm run build:qa` (หรือ `MODE=<dev\|qa\|prd> npm run build`) | ไม่มี script test/lint ใน package.json | กำลังแก้ |
