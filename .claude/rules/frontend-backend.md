---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,html,scss,css}"
  - "**/*.{cs,php}"
  - "**/Program.cs"
  - "**/Startup.cs"
---
# Frontend / Backend Rules

## UI / State
- React: state ให้ใกล้ผู้ใช้ที่สุด · server state ใช้ React Query/SWR · global state เฉพาะที่แชร์จริง · `useEffect` ต้องมี cleanup และ deps ครบ
- Angular: ใช้ `async` pipe / `takeUntilDestroyed()` แทน manual subscribe · `ChangeDetectionStrategy.OnPush` · signals สำหรับ local state
- ห้ามเก็บ token/ข้อมูลอ่อนไหวใน `localStorage` (ใช้ HttpOnly cookie) · ห้าม `dangerouslySetInnerHTML` / `[innerHTML]` ที่ไม่ sanitize
- API calls รวมศูนย์ที่ service/client เดียว (interceptor จัดการ auth, error, retry) ไม่ยิง fetch กระจายใน component

## CORS
- ระบุ origin แบบ allow-list ชัดเจน (ภายในองค์กร) · ห้าม `*` คู่กับ credentials
- .NET: `AddCors(policy)` + `app.UseCors()` อยู่หลัง `UseRouting` และก่อน `UseAuthentication/UseAuthorization`
- Node: `cors({ origin: [...], credentials: true })` · PHP: ตอบ preflight `OPTIONS` ด้วย 204 และ header ครบ
- CORS ที่ IIS (`web.config` customHeaders) กับในแอปห้ามตั้งซ้ำกัน (header ซ้ำทำให้ browser ปฏิเสธ)

## Error Handling
- Backend: global handler เดียว → .NET ใช้ `ProblemDetails` (RFC 7807) + `UseExceptionHandler` · Node ใช้ error middleware ตัวสุดท้าย
- ห้ามส่ง stack trace/ข้อความ exception/SQL ออก client บน Prod · ส่งเฉพาะ `traceId` + ข้อความทั่วไป
- Status code ต้องตรงความหมาย (400/401/403/404/409/422/500) · ห้ามกลืน exception (`catch {}` เปล่า)
- Frontend: interceptor แปลง error เป็นข้อความผู้ใช้ + รองรับ 401 (redirect/refresh) และ network error

## Structured Logging
- .NET: `ILogger` + message template (`"Order {OrderId} failed"`) ไม่ใช้ string interpolation · Serilog/JSON sink
- Node: `pino`/`winston` แบบ JSON · PHP: Monolog JSON formatter
- ทุก request มี `correlationId`/`traceId` ส่งต่อข้ามบริการ · ระดับ log: Debug/Info/Warn/Error ตามความเหมาะสม
- ห้าม log รหัสผ่าน, token, connection string, เลขบัตร/PII เต็ม (mask)

## Header หลัง IIS Reverse Proxy (`X-Forwarded-For`, `X-Forwarded-Proto`)
- อย่าเชื่อ `X-Forwarded-*` จากทุกแหล่ง — เชื่อเฉพาะเมื่อมาจาก proxy ที่ไว้ใจ (IP ของ IIS/ARR)
- .NET: `app.UseForwardedHeaders(new ForwardedHeadersOptions { ForwardedHeaders = XForwardedFor | XForwardedProto, KnownProxies/KnownNetworks = ... })` เป็น middleware **ตัวแรก** · ห้ามล้าง `KnownProxies` โดยไม่จำกัดวง
- Node/Express: `app.set('trust proxy', <hop count หรือ IP>)` ห้ามตั้ง `true` ลอยๆ · ใช้ `req.ip`, `req.protocol`
- PHP: ใช้ `$_SERVER['HTTP_X_FORWARDED_FOR']` เฉพาะเมื่อ `REMOTE_ADDR` อยู่ใน trusted proxy list · เอา IP ซ้ายสุดที่ไม่ใช่ proxy
- IIS ARR ต้องเปิด "Preserve client IP" และตั้ง `HTTP_X_FORWARDED_PROTO` ผ่าน URL Rewrite (server variable) · ใช้ `X-Forwarded-Proto` ตัดสิน redirect HTTPS/secure cookie
