# 02 — todo-sample 書き換え: 2 行で済ませる

## 対話

> **後輩**「いよいよコード触りますね。」

> **先輩**「触るのは `src/main/java/todo/TodoServlet.java` の 1 箇所だけ。`service()` の冒頭。」

## Before

```java
// TodoServlet.java:19-20
String tenant = "public";
String user = "anonymous";
```

これは「proxy 通ってない」前提のハードコード。

## After

```java
String tenant = req.getHeader("X-Volta-Tenant-Id");
String user   = req.getHeader("X-Volta-User-Id");
if (tenant == null || tenant.isBlank()) tenant = "public";
if (user   == null || user.isBlank())   user   = "anonymous";
```

## diff

```diff
 protected void service(HttpServletRequest req, HttpServletResponse resp) throws IOException {
     resp.setContentType("application/json; charset=utf-8");

-    String tenant = "public";
-    String user = "anonymous";
+    String tenant = req.getHeader("X-Volta-Tenant-Id");
+    String user   = req.getHeader("X-Volta-User-Id");
+    if (tenant == null || tenant.isBlank()) tenant = "public";
+    if (user   == null || user.isBlank())   user   = "anonymous";
```

> **後輩**「2 行って言ってたのに 4 行ありますよ」

> **先輩**「**実質 2 行**。残り 2 行は fallback。ヘッダ無いとき (= proxy 経由じゃないとき) に
> 旧挙動 (public/anonymous) に落ちるようにしてる。これは README に書いてある通り。」

## なぜ fallback を残すか

> **後輩**「proxy 必須なら fallback 要らないんじゃないですか? 401 返した方が安全では?」

> **先輩**「いい指摘。本番ならその通り。ただ今回は:」

| ケース | 期待動作 |
|---|---|
| gateway 経由 (本番) | ヘッダから読む → テナント分離 |
| 直接アプリ叩く (ローカル開発) | `public/anonymous` バケットに落ちる |

> **先輩**「`README.md` の "anonymous 共有バケットは proxy を外した時に公開掲示板的に振る舞う。**意図された挙動**" ってのがこれ。本番でアプリを private network に置けば、直接アクセス自体できなくなる。」

> **後輩**「なるほど。**network レイヤで保証する** から、アプリは fallback 持っててもいい、と。」

## 認可 (role による分岐) は?

> **後輩**「あの、todo の `delete` を `ADMIN` だけにしたい、みたいな話は?」

> **先輩**「それは認可だから別レッスン。todo-sample の handson/03-rbac/ で扱ってる。**今日はテナント分離まで**。」

## ストアは無変更

`TodoStore` は `(tenant, user)` キーで動いている:

```java
// TodoStore.java の中身は触らない
ConcurrentHashMap<TenantUser, Map<Long, Todo>>
```

> **先輩**「`(tenant, user)` の値が `(public, anonymous)` でも `(tnt_a, alice)` でも同じコードで動く。**設計が良い**から認証導入に伴うリファクタが要らない。」

## ビルド確認

```bash
cd todo-sample
mvn -q compile
```

エラー無し。次は **gateway の前に立てる認証 backend (volta-auth-proxy)** の話。

## 次

→ [03-volta-auth-proxy起動.md](03-volta-auth-proxy起動.md)
