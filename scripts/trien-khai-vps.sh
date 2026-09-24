#!/usr/bin/env bash
# Đưa ứng dụng lên VPS Ubuntu với tên miền + HTTPS.
# Chạy SAU scripts/cai-dat-linux-mac.sh, tại thư mục dự án, bằng quyền root:
#   sudo bash scripts/trien-khai-vps.sh ten-mien-cua-ban.vn email@cua-ban.vn
set -euo pipefail
cd "$(dirname "$0")/.."
APP_DIR="$(pwd)"

DOMAIN="${1:-}"; EMAIL="${2:-}"
[ -n "$DOMAIN" ] && [ -n "$EMAIL" ] || { echo "Cách dùng: sudo bash scripts/trien-khai-vps.sh <tên-miền> <email>"; exit 1; }
[ "$(id -u)" = "0" ] || { echo "Hãy chạy bằng sudo"; exit 1; }
[ -f .env ] || { echo "Chưa có file .env. Chạy scripts/cai-dat-linux-mac.sh trước."; exit 1; }

# 1. Bắt buộc đặt mật khẩu đăng nhập vì trang sẽ mở ra Internet
if ! grep -q '^APP_USER=' .env; then
  read -rp  "Tên đăng nhập vào trang web: " U
  read -rsp "Mật khẩu đăng nhập vào trang web: " P; echo
  printf 'APP_USER=%s\nAPP_PASSWORD=%s\n' "$U" "$P" >> .env
fi
chmod 600 .env

echo "== Cài Nginx, Certbot, PM2 =="
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx ufw
command -v pm2 >/dev/null || npm install -g pm2

echo "== Chạy ứng dụng nền bằng PM2 =="
pm2 describe az-office >/dev/null 2>&1 && pm2 restart az-office --update-env || pm2 start server.js --name az-office --cwd "$APP_DIR"
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null

echo "== Cấu hình Nginx cho $DOMAIN =="
cat > /etc/nginx/sites-available/az-office <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    client_max_body_size 20m;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX
ln -sf /etc/nginx/sites-available/az-office /etc/nginx/sites-enabled/az-office
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "== Tường lửa: chỉ mở SSH, HTTP, HTTPS =="
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

echo "== Cấp chứng chỉ HTTPS miễn phí (Let's Encrypt) =="
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

echo "== Sao lưu CSDL tự động mỗi ngày lúc 2h sáng (giữ 14 ngày) =="
mkdir -p /var/backups/azoffice
cat > /etc/cron.d/azoffice-backup <<'CRON'
0 2 * * * root sudo -u postgres pg_dump azoffice | gzip > /var/backups/azoffice/azoffice-$(date +\%F).sql.gz && find /var/backups/azoffice -name '*.sql.gz' -mtime +14 -delete
CRON

echo
echo "Xong! Mở https://$DOMAIN"
