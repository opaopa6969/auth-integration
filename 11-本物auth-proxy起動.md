# 11 — 本物 auth-proxy 起動: DB / JWT / .env

## 対話

> **後輩**「本物の volta-auth-proxy って、どこからどう起動するんですか?」

> **先輩**「依存が 3 つ要る。**Postgres**、**JWT 鍵ペア**、**.env**。順にやる。」

## 0. ソース取得とビルド

> **先輩**「auth-integration の隣に各 repo を clone しておく。まとめてやるなら
> `./setup.sh` (auth-integration 直下) で 4 repo 一発。手で 1 個だけ要るなら下記。」

```bash
git clone https://github.com/opaopa6969/volta-auth-proxy
cd volta-auth-proxy
mvn -DskipTests package
# → target/volta-auth-proxy-0.3.0-SNAPSHOT.jar が出来る
```

## 1. Postgres を立てる (dev 独立)

> **後輩**「本番 DB に dev のユーザが混ざるの嫌ですよね。」

> **先輩**「**完全に別コンテナ**で立てる。本番が 25429 なら dev は 25432、みたいに port をずらす。」

```bash
docker run -d --name volta-auth-postgres-dev \
  -e POSTGRES_USER=volta -e POSTGRES_PASSWORD=volta -e POSTGRES_DB=volta_auth \
  -p 25432:25432 postgres:16-alpine
```

確認:

```bash
$ docker ps --format 'table {{.Names}}\t{{.Ports}}'
NAMES                       PORTS
volta-auth-postgres-dev     0.0.0.0:25432->25432/tcp
```

## 2. JWT 鍵ペアを生成

> **後輩**「これは本番と共有しちゃダメ?」

> **先輩**「**ダメ**。dev のセッションを本番に持ち込めなくする。dev 用に新規生成。」

> **先輩**「ちなみに **この章の 2〜3 (鍵生成 + .env 作成) は `./dev/gen-dev-env.sh` 一発**で済む。
> openssl の鍵生成も PEM の `\n` エスケープも自動。中身を理解したいなら下記を手でやれ。
> 勉強会で手っ取り早く動かしたいならスクリプトでいい。」

```bash
mkdir -p auth-integration/dev
cd auth-integration/dev

openssl genrsa -out jwt-private.pem 2048
openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem

# 追加で 2 つのランダム secret
openssl rand -hex 32 > jwt-key-encryption-secret.txt
openssl rand -hex 16 > volta-service-token.txt
```

> **後輩**「`.pem` って公開鍵と秘密鍵ですよね。秘密鍵 GitHub に push しちゃダメですよね。」

> **先輩**「**絶対にダメ**。`.gitignore` に `dev/` を入れろ。`.env.template` だけ commit する。」

## 3. `.env` を書く

最小限の `auth-proxy-dev.env`:

```bash
PORT=27070                            # 本番 :27070 と衝突回避
DB_HOST=localhost
DB_PORT=25432                        # dev Postgres
DB_NAME=volta_auth
DB_USER=volta
DB_PASSWORD=volta
BASE_URL=http://localhost:27070
JWT_ISSUER=volta-auth-dev
JWT_AUDIENCE=volta-apps-dev
JWT_PRIVATE_KEY_PEM="$(awk '{printf "%s\\n", $0}' dev/jwt-private.pem)"
JWT_PUBLIC_KEY_PEM="$(awk '{printf "%s\\n", $0}' dev/jwt-public.pem)"
JWT_TTL_SECONDS=300
SESSION_TTL_SECONDS=28800
JWT_KEY_ENCRYPTION_SECRET=<dev/jwt-key-encryption-secret.txt の中身>
ALLOWED_REDIRECT_DOMAINS=localhost,127.0.0.1
VOLTA_SERVICE_TOKEN=<dev/volta-service-token.txt の中身>
DEV_MODE=true                        # ← Magic Link が response に link を返してくれる
LOCAL_BYPASS_CIDRS=                  # ← 空にしないと全リクエスト anonymous で通る
APP_CONFIG_PATH=dev/volta-config-dev.yaml
NOTIFICATION_CHANNEL=none            # メール送らない
WEBHOOK_ENABLED=false
AUDIT_SINK=postgres
```

> **後輩**「`JWT_PRIVATE_KEY_PEM` の `\\n` ってなんですか?」

> **先輩**「PEM は改行が多い。env 変数として渡すには改行を `\n` リテラルに変換する必要がある。
> `awk '{printf "%s\\n", $0}'` でやってる。」

### `volta-config-dev.yaml` (apps の定義)

```yaml
version: 1

# Part 2 では外部 IdP なし
idp: []

apps:
  - id: app-todo
    url: http://localhost:28888
    allowed_roles: [MEMBER, ADMIN, OWNER]
```

## 4. 起動

```bash
cd /path/to/volta-auth-proxy
set -a && . /path/to/auth-integration/dev/auth-proxy-dev.env && set +a
nohup java -jar target/volta-auth-proxy-0.3.0-SNAPSHOT.jar > /tmp/auth-proxy-dev.log 2>&1 &
```

> **後輩**「`set -a` って?」

> **先輩**「**bash の魔法**。直後の `source` で読み込んだ変数を全部 export する。
> 個別に `export A=1` `export B=2` 書かなくていい。」

## 5. healthz で起動確認

```bash
$ curl -s http://localhost:27070/healthz
{"status":"ok"}
```

## 6. 401 が返ることを確認 (バイパス無効化の検証)

```bash
$ curl -s -D - http://localhost:27070/auth/verify | head -8
HTTP/1.1 401 Unauthorized
Date: Sun, 24 May 2026 23:40:52 GMT
Content-Type: text/plain
X-Request-Id: b8a7a75e-ca6b-4213-81ce-a097f5c82856
X-Volta-Auth-Reason: cookie_absent_401
Content-Length: 0
```

`X-Volta-Auth-Reason: cookie_absent_401` が出れば成功。
ここで `X-Volta-Auth-Source: local-bypass` が出る場合は `LOCAL_BYPASS_CIDRS` が空でない。

## 詰みポイント

### A. JWT 鍵の改行が抜ける

```
ERROR: Could not parse RSA private key
```

→ `\n` への変換が抜けてる。`awk '{printf "%s\\n", $0}'` を確認。

### B. Postgres が空 (schema 未作成)

```
ERROR: relation "users" does not exist
```

→ auth-proxy は起動時にマイグレーション自動実行する。**起動ログを見る**:

```
[main] INFO ... - Running migration 001_create_users.sql
```

数十秒かかることがある。すぐに healthz が返らないのは正常。

### C. ポート衝突

```
java.net.BindException: Address already in use
```

→ 同じポートで他プロセスが listen してる。`ss -tlnp | grep 27070` で確認。
本記録では `:7071` を `building-hierarchy` が使ってたので `:27070` にずらした。

## 次

→ [12-gateway-todo連携.md](12-gateway-todo連携.md)
