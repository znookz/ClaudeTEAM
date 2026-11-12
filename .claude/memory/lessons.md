# Lessons Learned (บทเรียนของทีม)

**รูปแบบ**: `- [YYYY-MM-DD] [repo/area] บทเรียน → วิธีที่ถูก`

**กติกา**
- เก็บเฉพาะสิ่งที่เกิดซ้ำ/พลาดจริง ไม่เก็บเรื่องทั่วไป
- ≤ 1 บรรทัดต่อรายการ
- ห้ามใส่ secret/password/connection string/token
- เพิ่มรายการต้องผ่านผู้ใช้อนุมัติ (leader เสนอ → ส่ง agent ที่มี Edit เป็นคนเขียน)

## รายการ
- [2026-11-12] [infra/web.config] แก้ web.config โดยไม่ backup แล้วย้อนไม่ได้ → copy เป็น `web.config.bak-<yyyyMMdd>` ก่อนแก้ทุกครั้ง
- [2026-11-12] [db/sql] UPDATE/DELETE ไม่มี WHERE กระทบทั้งตาราง → เขียน SELECT ด้วย WHERE เดียวกันตรวจจำนวนแถวก่อน, ทดสอบบน Dev/UAT, เตรียม Rollback script
- [2026-11-12] [infra/iis] รัน iisreset/Restart-WebAppPool เองกระทบผู้ใช้ → เสนอคำสั่งให้ผู้ใช้รันเอง
