---
name: github-runner-workflow
description: Create a GitHub Actions workflow (.yml) for a self-hosted Windows Server runner that builds a frontend and deploys to IIS, and guide runner install/removal/offline troubleshooting. Use when the user asks for a CI/CD workflow, GitHub runner, or deploy-to-IIS pipeline.
---
# GitHub Runner Workflow (Windows self-hosted -> IIS)

## 1. กฎ
- **ห้ามรัน** deploy / `iisreset` / `git push` เอง — สร้างไฟล์ .yml แล้วให้ผู้ใช้ commit/push เอง
- **ห้ามใส่ secret/token/password ใน yml** — ใช้ GitHub Secrets (`${{ secrets.X }}`); runner token ห้ามแปะในแชท
- ถามผู้ใช้ก่อนเขียน: (1) repo `<owner/repo>` (2) branch trigger (3) labels runner (4) build script เช่น `npm run build:xxx` (5) โฟลเดอร์ deploy (6) node version (7) ใช้ npm หรือ pnpm

## 2. ตรวจ package.json ก่อนเขียน
`Grep "\"build" package.json` ให้แน่ใจว่า script มีจริง — บทเรียน: `build:ecom-qa` ไม่มีจริงทำให้ workflow fail

## 3. Template (อ้างอิง WEB-WPT\.github\workflows\dohome-uat.yml)
```yaml
name: Deploy <App> (<env>)
on:
  push:
    branches: [<branch>]
  workflow_dispatch:
concurrency:
  group: <unique-group>
  cancel-in-progress: false
env:
  DEPLOY_TARGET: 'C:\inetpub\wwwroot\<folder>'
defaults:
  run:
    shell: cmd
jobs:
  build-deploy:
    if: github.repository == '<owner/repo>'
    runs-on: [self-hosted, windows, <label>]
    steps:
      - uses: actions/checkout@v4
        with:
          clean: false            # ไม่ลบ node_modules
      - uses: actions/setup-node@v4
        with:
          node-version: <22>
      - name: Install (only if node_modules missing)
        run: |
          if not exist node_modules (
            call npm install
            if errorlevel 1 exit /b 1
          ) else (
            echo node_modules found, skip install
          )
      - name: Build
        run: |
          call npm run <script>
          if errorlevel 1 exit /b 1
      - name: Deploy to IIS
        run: |
          robocopy "%CD%\dist" "%DEPLOY_TARGET%" /MIR /R:3 /W:5 /NP /NFL /NDL
          if errorlevel 8 (
            echo robocopy failed with ExitCode %ERRORLEVEL%
            exit /b 1
          )
          exit /b 0
```
- robocopy exit code **>= 8 = fail** (0-7 = สำเร็จ) จึงต้องจบด้วย `exit /b 0`
- **คำเตือน `/MIR`**: ลบไฟล์ปลายทางที่ไม่อยู่ใน `dist` — `web.config` ที่อยู่เฉพาะปลายทางจะหาย → backup ก่อน หรือใส่ไว้ใน `public/` ให้ติดไปกับ dist (หรือใช้ `/XF web.config`)
- pnpm: เพิ่ม `npm i -g pnpm` / `call pnpm install --frozen-lockfile` / `call pnpm run <script>`

## 4. ติดตั้ง / ลบ Runner (ผู้ใช้รันเอง, Admin PowerShell/cmd)
```cmd
cd C:\actions-runner
config.cmd --url https://github.com/<owner/repo> --token <TOKEN_จากหน้า_Settings> --labels uat,windows --runasservice
svc.cmd status          &:: svc.cmd start | stop
config.cmd remove --token <REMOVE_TOKEN>
```
- Token ได้จาก GitHub > Settings > Actions > Runners > New runner (หมดอายุเร็ว) — ผู้ใช้กรอกเองในเครื่อง ห้ามส่งมาในแชท

## 5. Runner Offline — สาเหตุที่พบบ่อย
- Service ไม่รัน: `Get-Service actions.runner.*`
- ออกพอร์ต 443 ไม่ได้: `Test-NetConnection github.com -Port 443` (รวม `api.github.com`, `*.actions.githubusercontent.com`)
- Proxy/Firewall ขององค์กรบล็อก
- ดู log: `Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50`

## 6. ข้อควรระวัง
- ไฟล์ workflow ต้องอยู่ใน **branch ที่ trigger** (push ไป branch นั้นต้องมีไฟล์ใน branch นั้น)
- `_work` workspace ต้องมี `node_modules` ถ้า copy เอง (step install ข้ามเมื่อมีโฟลเดอร์)
- `package.json`/lockfile เปลี่ยน → ต้องลบ `node_modules` ใน `_work` ก่อน ไม่งั้นไม่ install ซ้ำ
- ชื่อ `concurrency.group` ต้องไม่ซ้ำระหว่าง workflow ที่ไม่ควรบล็อกกัน
