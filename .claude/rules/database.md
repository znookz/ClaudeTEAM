---
paths:
  - "**/*.sql"
  - "**/Migrations/**"
  - "**/db/**"
  - "**/*Repository*.cs"
  - "**/*DbContext*.cs"
  - "**/*{Dao,Query,Queries}*.{cs,ts,js,php}"
---
# Database Rules (MS SQL Server / PostgreSQL)

## Query
- **Parameterized 100%**: `SqlParameter`/`NpgsqlParameter`, Dapper `@param`, EF LINQ, `pg` `$1`, PDO `prepare()` — ห้ามต่อสตริง SQL จาก input เด็ดขาด
- ชื่อตาราง/คอลัมน์ที่เป็น dynamic ต้องผ่าน allow-list (whitelist) เท่านั้น
- **ห้าม `SELECT *`** — ระบุคอลัมน์ที่ใช้จริง · ทุก list endpoint ต้องมี paging (`OFFSET/FETCH`, `LIMIT`) และ `ORDER BY` ที่ deterministic
- ห้ามใช้ฟังก์ชันครอบคอลัมน์ใน `WHERE/JOIN` (เช่น `WHERE YEAR(col)=..`, `CAST(col ..)`) เพราะทำให้ index ใช้ไม่ได้ (non-SARGable)
- `UPDATE`/`DELETE` ต้องมี `WHERE` เสมอ · ทดสอบด้วย `SELECT` เงื่อนไขเดียวกันก่อน · ใช้ transaction + ตรวจ `@@ROWCOUNT`/`GET DIAGNOSTICS`

## Index
- ก่อนเขียน/แก้ query ตรวจว่าคอลัมน์ใน `WHERE/JOIN/ORDER BY` มี index รองรับ (ดู `sys.indexes` / `pg_indexes`) และ FK มี index
- ดู execution plan (`SET SHOWPLAN_XML ON` / `EXPLAIN`) หา Table Scan, Key Lookup, Sort ที่หนัก
- ไม่สร้าง index เกินจำเป็น (กระทบ write) — เสนอ `CREATE INDEX` พร้อมเหตุผลและ `DROP INDEX` สำหรับ rollback

## Deadlock / Connection Pool
- เข้าถึงตารางตามลำดับเดียวกันทุก transaction · transaction สั้น ไม่มี user interaction/HTTP call ภายใน
- ใช้ `READ_COMMITTED_SNAPSHOT` (MSSQL) / MVCC (PG) ลด blocking · retry อัตโนมัติเมื่อ error 1205 (MSSQL) / 40P01 (PG) แบบจำกัดครั้ง
- Connection: `using`/`await using`/`finally` ปิดทุกครั้ง · ห้ามเปิด connection ใน loop · ไม่เก็บ connection เป็น static
- ตรวจ `Max Pool Size` (default 100) เทียบจำนวน instance × concurrency · อาการ "timeout obtaining connection from the pool" = leak หรือ query ช้า
- ตั้ง `CommandTimeout` ให้สมเหตุผล · Node ใช้ pool เดียวทั้งแอป (`new Pool({ max })`)

## Rollback & ความปลอดภัย
- ทุก migration/script ต้องมี **แผน Rollback** (script ย้อนกลับ หรือ backup ที่ระบุชัด) ใส่ไว้ในหัวไฟล์/PR
- แยก DDL ที่ย้อนไม่ได้ (DROP COLUMN, ลด type) เป็นขั้นตอนต่างหาก + ขอยืนยันจากผู้ใช้
- ห้าม `DROP`, `TRUNCATE` และห้ามรันบน Production เอง — ส่ง script ให้ผู้ใช้/DBA รัน
- Connection string/รหัสผ่านอยู่ใน secret store/env ไม่ commit และไม่แสดงในแชท · ใช้ least-privilege account (ไม่ใช้ `sa`/`postgres`)
