# =====================================================
# DynLove - Windows VPS Setup Script
# Chạy: PowerShell as Administrator
# =====================================================

$ErrorActionPreference = "Stop"
$APP_DIR = "C:\apps\dynlove-backend"
$DOMAIN  = "api.dynlove.app"   # ĐỔI THÀNH DOMAIN CỦA BẠN

Write-Host "=== [1/6] Cài Chocolatey ===" -ForegroundColor Cyan
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = 3072
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

Write-Host "=== [2/6] Cài Node.js 20 LTS + PostgreSQL 16 + Caddy + NSSM ===" -ForegroundColor Cyan
choco install -y nodejs-lts postgresql16 caddy nssm --no-progress

# Reload PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "=== [3/6] Tạo database + user ===" -ForegroundColor Cyan
$PG = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
$PGPASS = "dynlove_root_pw_change_me"
$APPPASS = "dynlove_app_pw_change_me"

# Set password cho postgres user
& $PG -U postgres -c "ALTER USER postgres WITH PASSWORD '$PGPASS';"

$sql = @"
DO `$`$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='dynlove_app') THEN
    CREATE ROLE dynlove_app LOGIN PASSWORD '$APPPASS';
  END IF;
END `$`$;
"@
& $PG -U postgres -c $sql

& $PG -U postgres -c "SELECT 'CREATE DATABASE dynlove OWNER dynlove_app' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='dynlove')\gexec"

Write-Host "=== [4/6] Deploy backend code ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $APP_DIR | Out-Null
New-Item -ItemType Directory -Force -Path "$APP_DIR\logs" | Out-Null
# Copy toàn bộ folder backend/ từ máy bạn sang $APP_DIR qua WinSCP/RDP, hoặc git clone.

if (Test-Path "$APP_DIR\package.json") {
  Push-Location $APP_DIR
  npm install --omit=dev
  Pop-Location
}

# Tạo .env
@"
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://dynlove_app:$APPPASS@localhost:5432/dynlove
JWT_SECRET=$(-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_}))
JWT_EXPIRES=15m
REFRESH_EXPIRES_DAYS=30
"@ | Out-File -FilePath "$APP_DIR\.env" -Encoding utf8

Write-Host "=== [5/6] Đăng ký Windows Services ===" -ForegroundColor Cyan
nssm stop DynLoveBackend 2>$null; nssm remove DynLoveBackend confirm 2>$null
nssm install DynLoveBackend "C:\Program Files\nodejs\node.exe" "src\index.js"
nssm set DynLoveBackend AppDirectory $APP_DIR
nssm set DynLoveBackend AppStdout "$APP_DIR\logs\stdout.log"
nssm set DynLoveBackend AppStderr "$APP_DIR\logs\stderr.log"
nssm set DynLoveBackend AppRotateFiles 1
nssm set DynLoveBackend AppRotateBytes 10485760
nssm set DynLoveBackend Start SERVICE_AUTO_START
nssm start DynLoveBackend

# Caddy service
nssm stop Caddy 2>$null; nssm remove Caddy confirm 2>$null
$caddyfile = "C:\Caddyfile"
@"
$DOMAIN {
    reverse_proxy /socket.io/* 127.0.0.1:3000
    reverse_proxy 127.0.0.1:3000
}
"@ | Out-File -FilePath $caddyfile -Encoding ascii
nssm install Caddy "C:\ProgramData\chocolatey\bin\caddy.exe" "run --config $caddyfile"
nssm set Caddy Start SERVICE_AUTO_START
nssm start Caddy

Write-Host "=== [6/6] Mở Windows Firewall ===" -ForegroundColor Cyan
New-NetFirewallRule -DisplayName "DynLove-HTTP"  -Direction Inbound -Protocol TCP -LocalPort 80  -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "DynLove-HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "✅ HOÀN TẤT!" -ForegroundColor Green
Write-Host "Backend:  http://<IP_VPS>:3000/health"
Write-Host "Domain:   https://$DOMAIN/health  (nếu DNS đã trỏ về VPS)"
Write-Host "Logs:     $APP_DIR\logs\"
Write-Host ""
Write-Host "Lệnh hữu ích:"
Write-Host "  nssm restart DynLoveBackend"
Write-Host "  nssm status DynLoveBackend"
