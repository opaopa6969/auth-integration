# 03 — volta-auth-proxy: 認証 backend を立てる (今回は mock)

## 対話

> **後輩**「`volta-auth-proxy/` フォルダ覗いたら**空っぽ**だったんですが…」

> **先輩**「あー、本物はまだ clone してない。本物は別 repo (https://github.com/opaopa6969/volta-auth-proxy)
> で、Java + Spring。OIDC / SAML / Passkey / MFA まで揃った代物だ。」

> **後輩**「今回それ要りますか? todo の認証通すだけなのに…」

> **先輩**「**要らん**。今回は volta-gateway 同梱の **mock_auth example** で代用する。
> 全リクエストを承認して `X-Volta-*` ヘッダを返すだけのやつ。本物の代わりになる。」

## mock_auth が何をするか

```rust
// volta-gateway/examples/mock_auth.rs の核心部分
Response::builder()
    .status(200)
    .header("x-volta-user-id", "bench-user-001")
    .header("x-volta-email", "bench@example.com")
    .header("x-volta-tenant-id", "tenant-001")
    .body(Full::new(Bytes::new()))
```

**全リクエストに対して 200 + 固定の X-Volta-\* を返す**。
gateway はこれを `/auth/verify` 先として使う。

```mermaid
sequenceDiagram
    Client->>Gateway: GET /todos
    Gateway->>mock_auth: GET /auth/verify (forwarded cookies)
    mock_auth-->>Gateway: 200 + X-Volta-User-Id: bench-user-001<br/>X-Volta-Tenant-Id: tenant-001
    Gateway->>todo-sample: GET /todos<br/>X-Volta-User-Id: bench-user-001<br/>X-Volta-Tenant-Id: tenant-001
    todo-sample-->>Gateway: 200 [...]
    Gateway-->>Client: 200 [...]
```

## 本物と何が違うか

| 観点 | mock_auth | 本物 volta-auth-proxy |
|---|---|---|
| 認証判定 | 常に通す | Cookie/JWT 検証, OIDC, SAML, MFA, Passkey |
| 返すユーザ | 固定 `bench-user-001` | セッションから引いた本物のユーザ |
| Tenant | 固定 `tenant-001` | ユーザの所属テナント |
| 401 | 出さない | 未認証なら 401 |

> **後輩**「**全部通す mock** だと、認証してるかどうかわからないですね。」

> **先輩**「そう。だが今日の目的は **配管が通っているか** の確認。配管が通れば、mock を本物に差し替えるだけ。本物の起動が要るなら別記録で扱う。」

## 起動

```bash
cd volta-gateway
./target/release/examples/mock_auth 7070 &
# => mock auth listening on 127.0.0.1:7070
```

ヘルスチェック:

```bash
curl -s http://localhost:7070/healthz
# => {"status":"ok"}

curl -s -D - http://localhost:7070/auth/verify
# HTTP/1.1 200 OK
# x-volta-user-id: bench-user-001
# x-volta-email: bench@example.com
# x-volta-tenant-id: tenant-001
```

ちゃんと返してる。

## 本物 (volta-auth-proxy) に差し替えるとき

仕様: `auth.volta_url` に本物の URL を向けるだけで gateway は同じ動きをする。
本物起動には PostgreSQL と JWT secret が要る:

```bash
docker run --rm -d --name volta-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
export DATABASE_URL=postgres://postgres:postgres@localhost/postgres
export JWT_SECRET="$(openssl rand -hex 32)"

# 本物は Rust 実装の auth-server を使う (Java auth-proxy と 1:1 互換)
cargo run --release -p volta-auth-server
```

> **後輩**「これは今日やりません?」

> **先輩**「やらん。今日は配管。本物セットアップは `volta-gateway/docs/getting-started-ja.md`
> の §4 に詳しく書いてある。」

## 次

→ [04-volta-gateway設定.md](04-volta-gateway設定.md)
