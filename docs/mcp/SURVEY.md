# MCP 化調査 — auth-integration

## 概要

`auth-integration` は **todo-sample × volta-gateway × volta-auth-proxy の認証連携を段階的に体験するハンズオン手順書リポジトリ** である。

実行可能コードを独自に持たず、以下の構成要素のみで成り立つ:

- **手順ドキュメント** (30 ファイルの Markdown): Part 1 (mock auth / ローカル) → Part 2 (本物 auth-proxy / Magic Link・Passkey・Invite) → Part 3 (Google OIDC / Cloudflare Tunnel / 公開ドメイン) の 3 段階構成
- **docker-compose.yml / docker-compose.part3.yml**: 4 つの兄弟リポジトリを繋ぐ compose 定義
- **設定テンプレート** (`dev/`, `docker/`, `part3/`): gateway YAML・auth-proxy env・cloudflared config 等
- **setup.sh / gen-dev-env.sh**: 兄弟リポジトリの clone と JWT 鍵等の秘密情報生成

種類: **workspace** (複数プロジェクトを束する構成・手順集。実体なし)

## 判定と理由

**判定: `skip`**

理由:

1. **実行可能な能力を持たない**: サーバ・ライブラリ・CLI いずれでもなく、Markdown 手順書と compose/設定テンプレートのみ。エージェントが「呼ぶ」対象が存在しない。
2. **実体は各構成要素に属する**: 認証能力は `volta-auth-proxy`、プロキシ能力は `volta-gateway`、管理 UI は `volta-auth-console` がそれぞれ持ち、それらは独立リポジトリとして別途 MCP 化調査の対象になるべき。
3. **workspace は原則 skip**: 指示書の判断基準に従い、workspace / archive は原則 skip。中の個別リポジトリが別途調査対象。

## 公開候補

| kind | name | io / 説明 | 副作用 | 長時間 |
|---|---|---|---|---|
| resource | guide | ハンズオン構成手順の参照 | read | false |
| skill | auth-proxy-hands-on | 認証プロキシパターン構築手順(ヘッダ信頼モデル・mock→本物→Google OIDC) | none | false |

上記は**可能性のメモ**であり、このリポジトリから配ることを推奨しない。skill の中身は `volta-auth-proxy` 側に属するナレッジのほうが適切。

## 組み合わせ例

- `skill:auth-proxy-hands-on` → `volta__svc_add` / `volta__gateway_routes_apply` のように、構築手順に沿って volta 基盤操作を組み合わせる
- このリポジトリ自体は能力を持たないため、構成要素(`volta-auth-proxy` 等)の MCP 化が先。そちらから ability を公開すべき

## 依存と協調

| 相手 repo | 方向 | 能力 | 現在存在 | 備考 |
|---|---|---|---|---|
| todo-sample | depends_on | 認証対象アプリ(Java/Jetty) | yes | 兄弟ディレクトリ `../todo-sample` を build context に使用 |
| volta-gateway | depends_on | リバースプロキシ(Rust) / 唯一の入口 | yes | 兄弟ディレクトリ `../volta-gateway` を使用。catalog に volta-gateway 関連あり |
| volta-auth-proxy | depends_on | 認証 backend(Java) / OAuth2/OIDC/Magic Link/Passkey | yes | 兄弟ディレクトリ `../volta-auth-proxy` を使用。catalog id=volta-auth-proxy (retired) |
| volta-auth-console | depends_on | admin SPA(React) / ユーザ・テナント・セッション管理UI | yes | 兄弟ディレクトリ `../volta-auth-console` を使用。catalog id=volta-auth-console |

すべて **depends_on** (このリポジトリが相手に依存) の一方向。相手がこのリポジトリに依存してくる入口はない。

catalog 上の既存 MCP バックエンド: 4 リポジトリとも現時点で MCP バックエンド(`mcp` 項)を持たない。

## ライブラリのサーバ化

該当しない(ライブラリではない)。

## リスク

- `dev/` 配下に JWT 秘密鍵・`volta-service-token` 等が平文で配置される(`.gitignore` 対象だが誤コミットリスク)
- `docker-compose.yml` が兄弟リポジトリのローカルパス(`../volta-gateway` 等)に依存し、`setup.sh` で clone する前提。CI 環境等では未設定で失敗する

## 持ち主への質問

1. 認証構築手順を skill として配る場合、このリポジトリから出すか `volta-auth-proxy` 側で出すか
2. `volta-auth-proxy` は catalog で retired 扱いだが、このハンズオンでは現役で使われている。retired の理由と後継(`volta-auth-server`?)の関係
