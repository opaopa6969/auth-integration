#!/usr/bin/env bash
# =============================================================================
# dev/auth-proxy-dev.env と JWT 鍵一式を生成する (11-本物auth-proxy起動.md の自動化)
#
# 参加者が一番こけるポイント (openssl 鍵生成 + PEM の \n エスケープ + secret 4種) を
# 1 コマンドにまとめたもの。生成物はすべて gitignore 対象 (秘密)。
#
# 冪等: 既に在るファイルは触らない。鍵を作り直したいなら先に dev/*.pem を消す。
#
#   使い方:  ./dev/gen-dev-env.sh   (auth-integration 直下から)
#        or  cd dev && ./gen-dev-env.sh
# =============================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"   # dev/ に移動

gen() {  # gen <file> <生成コマンド...>
  local f="$1"; shift
  if [[ -e "$f" ]]; then
    echo "✓ $f : 既存 (skip)"
  else
    echo "↓ $f : 生成"
    "$@"
  fi
}

gen jwt-private.pem            openssl genrsa -out jwt-private.pem 2048
gen jwt-public.pem            openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem
gen jwt-key-encryption-secret.txt bash -c 'openssl rand -hex 32 > jwt-key-encryption-secret.txt'
gen volta-service-token.txt   bash -c 'openssl rand -hex 16 > volta-service-token.txt'

if [[ -e auth-proxy-dev.env ]]; then
  echo "✓ auth-proxy-dev.env : 既存 (skip)"
  echo "  作り直すなら: rm dev/auth-proxy-dev.env && ./dev/gen-dev-env.sh"
  exit 0
fi

echo "↓ auth-proxy-dev.env : 生成"
PRIV=$(awk '{printf "%s\\n", $0}' jwt-private.pem)
PUB=$(awk '{printf "%s\\n", $0}' jwt-public.pem)
ENC=$(cat jwt-key-encryption-secret.txt)
SVC=$(cat volta-service-token.txt)

cat > auth-proxy-dev.env <<EOF
# 自動生成 (dev/gen-dev-env.sh)。秘密。gitignore 対象。
# docker network 向けの値 (DB_HOST 等) は docker/auth-proxy.docker.env が上書きする。
PORT=27070
DB_HOST=localhost
DB_PORT=25432
DB_NAME=volta_auth
DB_USER=volta
DB_PASSWORD=volta
BASE_URL=http://localhost:27070
JWT_ISSUER=volta-auth-dev
JWT_AUDIENCE=volta-apps-dev
JWT_PRIVATE_KEY_PEM="$PRIV"
JWT_PUBLIC_KEY_PEM="$PUB"
JWT_TTL_SECONDS=300
SESSION_TTL_SECONDS=28800
JWT_KEY_ENCRYPTION_SECRET=$ENC
ALLOWED_REDIRECT_DOMAINS=localhost,127.0.0.1
VOLTA_SERVICE_TOKEN=$SVC
DEV_MODE=true
LOCAL_BYPASS_CIDRS=
APP_CONFIG_PATH=dev/volta-config-dev.yaml
NOTIFICATION_CHANNEL=none
WEBHOOK_ENABLED=false
AUDIT_SINK=postgres
EOF

echo
echo "完了。次: cd .. && docker compose up --build"
