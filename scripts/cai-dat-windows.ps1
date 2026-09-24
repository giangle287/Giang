# Cài Node.js LTS + PostgreSQL 16, tạo CSDL azoffice, tạo file .env và cài thư viện.
# Chạy trong PowerShell (Run as Administrator), tại thư mục dự án:
#   powershell -ExecutionPolicy Bypass -File scripts\cai-dat-windows.ps1
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$PgSuperPass = Read-Host "Đặt mật khẩu cho tài khoản quản trị 'postgres'"
$AppPass     = Read-Host "Đặt mật khẩu cho tài khoản CSDL 'azoffice'"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "Không có winget. Cài 'App Installer' từ Microsoft Store rồi chạy lại."
}

Write-Host "== Cài Node.js LTS ==" -ForegroundColor Cyan
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
} else { Write-Host "Node.js đã có: $(node -v)" }

Write-Host "== Cài PostgreSQL 16 ==" -ForegroundColor Cyan
$PgBin = "C:\Program Files\PostgreSQL\16\bin"
if (-not (Test-Path "$PgBin\psql.exe")) {
  winget install --id PostgreSQL.PostgreSQL.16 -e --accept-package-agreements --accept-source-agreements `
    --override "--mode unattended --unattendedmodeui none --superpassword `"$PgSuperPass`" --serverport 5432"
} else { Write-Host "PostgreSQL 16 đã có." }

# Nạp lại PATH để dùng được node/npm vừa cài
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User") + ";$PgBin"

Write-Host "== Tạo CSDL azoffice ==" -ForegroundColor Cyan
$env:PGPASSWORD = $PgSuperPass
$PassSql = $AppPass.Replace("'", "''")
$exists = & psql -U postgres -h localhost -tAc "SELECT 1 FROM pg_roles WHERE rolname='azoffice'"
if ($exists -ne "1") { & psql -U postgres -h localhost -c "CREATE USER azoffice WITH PASSWORD '$PassSql';" }
else { & psql -U postgres -h localhost -c "ALTER USER azoffice WITH PASSWORD '$PassSql';" }
$db = & psql -U postgres -h localhost -tAc "SELECT 1 FROM pg_database WHERE datname='azoffice'"
if ($db -ne "1") { & psql -U postgres -h localhost -c "CREATE DATABASE azoffice OWNER azoffice;" }
Remove-Item Env:PGPASSWORD

Write-Host "== Tạo file .env ==" -ForegroundColor Cyan
@"
DATABASE_URL=postgresql://azoffice:$([uri]::EscapeDataString($AppPass))@localhost:5432/azoffice
PORT=3000
"@ | Set-Content -Encoding ascii .env

Write-Host "== Cài thư viện ==" -ForegroundColor Cyan
npm install

Write-Host "`nXong! Chạy 'npm start' rồi mở http://localhost:3000" -ForegroundColor Green
