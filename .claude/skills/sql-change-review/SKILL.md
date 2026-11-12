---
name: sql-change-review
description: Template and checklist for reviewing a SQL DML/DDL change — scripted change, Rollback script, SELECT with the same WHERE to verify row count, and Dev/UAT testing first. Use before proposing any UPDATE/DELETE/INSERT/ALTER on MS SQL Server or PostgreSQL.
---
# SQL Change Review

**กฎ**: ห้าม `DROP`/`TRUNCATE` · ห้าม `UPDATE`/`DELETE` ไม่มี `WHERE` · ไม่รันบน Production เอง · ทดสอบ Dev/UAT ก่อนเสมอ · ห้ามแสดง connection string/รหัสผ่าน

## Template (ใช้ทุกครั้ง)
```sql
-- 1) ตรวจจำนวนแถวก่อน (WHERE เดียวกับ DML)
SELECT COUNT(*) AS affected FROM dbo.<table> WHERE <condition>;
SELECT TOP 20 * FROM dbo.<table> WHERE <condition>;   -- PostgreSQL: LIMIT 20

-- 2) สำรองแถวที่จะแก้ (ใช้ใน Rollback)
SELECT * INTO dbo.<table>_bak_<yyyyMMdd> FROM dbo.<table> WHERE <condition>;

-- 3) DML/DDL จริง (ใน transaction)
BEGIN TRAN;
UPDATE dbo.<table> SET <col> = <value> WHERE <condition>;
-- ตรวจ @@ROWCOUNT ต้องเท่ากับ affected ข้างบน
-- COMMIT;   -- ผู้ใช้ยืนยันหลังตรวจ
-- ROLLBACK; -- ถ้าจำนวนไม่ตรง

-- 4) Rollback script
UPDATE t SET t.<col> = b.<col>
FROM dbo.<table> t JOIN dbo.<table>_bak_<yyyyMMdd> b ON b.<pk> = t.<pk>;
```

## Checklist
- [ ] SELECT COUNT ด้วย WHERE เดียวกัน → จำนวนตรงกับที่คาด
- [ ] WHERE ใช้ key/index ที่เหมาะสม ไม่กวาดทั้งตาราง
- [ ] DDL (ALTER/CREATE): มี script ย้อนกลับ + ตรวจ dependency (view/SP/FK)
- [ ] มี Rollback script พร้อมใช้
- [ ] ทดสอบบน Dev/UAT แล้ว (ระบุ DB + จำนวนแถว)
- [ ] ผู้ใช้ยืนยันก่อนรันบน Production

## รายงาน (≤ 10 บรรทัด)
`SQL · จำนวนแถวที่คาด/จริง · Rollback · ผลทดสอบ Dev/UAT · ความเสี่ยง (lock/เวลา/ขนาด)`
