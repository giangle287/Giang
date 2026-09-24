#!/usr/bin/env bash
# Cài Node.js LTS + PostgreSQL, tạo CSDL azoffice, tạo file .env và cài thư viện.
# Hỗ trợ Ubuntu/Debian và macOS (cần Homebrew). Chạy tại thư mục dự án:
#   bash scripts/cai-dat-linux-mac.sh
set -euo pipefail
cd "$(dirname "$0")/.."

read -rsp "Đặt mật khẩu cho tài khoản CSDL 'azoffice': " APP_PASS; echo
[ -n "$APP_PASS" ] || { echo "Mật khẩu không được để trống"; exit 1; }

OS="$(uname -s)"
if [ "$OS" = "Linux" ]; then
  echo "== Cài Node.js LTS =="
  if ! command -v node >/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
  echo "== Cài PostgreSQL =="
  if ! command -v psql >/dev/null; then
    sudo apt-get update && sudo apt-get install -y postgresql
  fi
  sudo systemctl enable --now postgresql 2>/dev/null || sudo service postgresql start
  PSQL=(sudo -u postgres psql -v ON_ERROR_STOP=1)
elif [ "$OS" = "Darwin" ]; then
  command -v brew >/dev/null || { echo "Cần cài Homebrew trước: https://brew.sh"; exit 1; }
  echo "== Cài Node.js LTS và PostgreSQL 16 =="
  command -v node >/dev/null || brew install node
  brew list postgresql@16 >/dev/null 2>&1 || brew install postgresql@16
  brew services start postgresql@16
  export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
  sleep 3
  PSQL=(psql -v ON_ERROR_STOP=1 -d postgres)
else
  echo "Hệ điều hành chưa hỗ trợ: $OS"; exit 1
fi

echo "== Tạo CSDL azoffice =="
PASS_SQL="${APP_PASS//\'/\'\'}"
if [ "$("${PSQL[@]}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='azoffice'")" = "1" ]; then
  "${PSQL[@]}" -c "ALTER USER azoffice WITH PASSWORD '$PASS_SQL';"
else
  "${PSQL[@]}" -c "CREATE USER azoffice WITH PASSWORD '$PASS_SQL';"
fi
if [ "$("${PSQL[@]}" -tAc "SELECT 1 FROM pg_database WHERE datname='azoffice'")" != "1" ]; then
  "${PSQL[@]}" -c "CREATE DATABASE azoffice OWNER azoffice;"
fi

echo "== Tạo file .env =="
ENC_PASS="$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$APP_PASS")"
printf 'DATABASE_URL=postgresql://azoffice:%s@localhost:5432/azoffice\nPORT=3000\n' "$ENC_PASS" > .env

echo "== Cài thư viện =="
npm install

echo
echo "Xong! Chạy 'npm start' rồi mở http://localhost:3000"
