---
name: db-optimize
description: Analyze slow queries, check indexes, and verify connection pooling for MS SQL Server and PostgreSQL. Use when a query/endpoint is slow, DB CPU is high, deadlocks or blocking occur, or the app reports "timeout obtaining connection from the pool".
---
# DB Optimize (วิเคราะห์ก่อน แก้ทีหลัง)

**กฎ**: รันเฉพาะ SELECT/EXPLAIN บน Dev/UAT · ผลลัพธ์ `TOP 10`/`LIMIT 10` · ห้าม `DROP`/`TRUNCATE`/DML ไม่มี `WHERE` · ห้ามแสดง connection string · ทุกข้อเสนอแก้ต้องมี Rollback · รายงาน ≤ 15 บรรทัด

## 1. หา Slow Query
**MSSQL** (ช้าสุดตามเวลาเฉลี่ย)
```sql
SELECT TOP 10 qs.total_elapsed_time/qs.execution_count/1000 AS avg_ms, qs.execution_count,
  SUBSTRING(st.text,(qs.statement_start_offset/2)+1,
   ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS stmt
FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY avg_ms DESC;
```
**PostgreSQL** (ต้องเปิด `pg_stat_statements`)
```sql
SELECT left(query,120) AS q, calls, round(mean_exec_time::numeric,1) AS mean_ms, round(total_exec_time::numeric) AS total_ms
FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;
```

## 2. ดู Execution Plan
- MSSQL: `SET STATISTICS IO, TIME ON;` + `SET SHOWPLAN_XML ON;` (plan โดยไม่รัน) — หา Table/Index Scan, Key Lookup, Sort/Hash spill, estimate ≠ actual
- PostgreSQL: `EXPLAIN (ANALYZE, BUFFERS)` **รัน query จริง** → ใช้กับ SELECT เท่านั้น หรือครอบด้วย `BEGIN READ ONLY; ... ROLLBACK;` · หา `Seq Scan` บนตารางใหญ่, `rows` estimate เพี้ยน

## 3. ตรวจ Index
**MSSQL**: missing index
```sql
SELECT TOP 10 d.statement AS tbl, d.equality_columns, d.inequality_columns, d.included_columns, s.user_seeks, s.avg_user_impact
FROM sys.dm_db_missing_index_details d
JOIN sys.dm_db_missing_index_groups g ON g.index_handle = d.index_handle
JOIN sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle
ORDER BY s.user_seeks * s.avg_user_impact DESC;
```
**PostgreSQL**: ตารางที่ scan แบบ sequential มากกว่าใช้ index
```sql
SELECT relname, seq_scan, idx_scan, n_live_tup FROM pg_stat_user_tables WHERE seq_scan > idx_scan ORDER BY seq_scan DESC LIMIT 10;
```
เช็กด้วย: คอลัมน์ใน `WHERE/JOIN/ORDER BY` มี index? · FK มี index? · query non-SARGable (ฟังก์ชันครอบคอลัมน์)? · `SELECT *` ดึงเกินจำเป็น? · index ซ้ำซ้อน/ไม่ถูกใช้ (กระทบ write)?
**Missing index DMV เป็นแค่คำแนะนำ** — รวม/ตัดซ้ำก่อนเสนอ `CREATE INDEX` (พร้อม `DROP INDEX` เป็น rollback)

## 4. Connection Pooling / Blocking / Deadlock
```sql
-- MSSQL: จำนวน session ต่อแอป (leak มักเห็นยอดสูงผิดปกติ) + blocking ปัจจุบัน
SELECT TOP 10 program_name, host_name, COUNT(*) AS sessions FROM sys.dm_exec_sessions WHERE is_user_process=1 GROUP BY program_name, host_name ORDER BY sessions DESC;
SELECT blocking_session_id, session_id, wait_type, wait_time, DB_NAME(database_id) AS db FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
-- MSSQL: deadlock ล่าสุดจาก system_health
SELECT TOP 3 CAST(event_data AS xml) AS deadlock FROM sys.fn_xe_file_target_read_file('system_health*.xel',NULL,NULL,NULL) WHERE object_name='xml_deadlock_report' ORDER BY timestamp_utc DESC;
-- PostgreSQL: connection ตามสถานะ + คนรอ lock
SELECT state, count(*) FROM pg_stat_activity WHERE datname = current_database() GROUP BY state;
SELECT pid, now()-query_start AS age, left(query,100) AS q FROM pg_stat_activity WHERE wait_event_type = 'Lock';
```
ตรวจโค้ด/config (ด้วย `Grep` ไม่อ่านทั้งโฟลเดอร์): `Max Pool Size`/`Maximum Pool Size` (default 100) เทียบ instance × concurrency · connection ปิดทุกเส้นทาง (`using`/`await using`/`finally`) · ไม่เปิด connection ใน loop · Node ใช้ `Pool` ตัวเดียว · `CommandTimeout` สมเหตุผล · transaction สั้น ลำดับเข้าถึงตารางเหมือนกัน
**ห้ามแสดงค่า connection string** — ระบุแค่ชื่อพารามิเตอร์ที่ตรวจ

## 5. รายงาน (≤ 15 บรรทัด)
`Query/endpoint ที่ช้า (avg_ms, calls) → สาเหตุ (จาก plan) → วิธีแก้ที่เสนอ (SQL/โค้ด) → ผลที่คาดหวัง → Rollback → ความเสี่ยง` · ถ้าต้องรัน DDL/DML จริง ให้ส่ง script ให้ผู้ใช้/DBA รันเอง
