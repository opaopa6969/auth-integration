#!/usr/bin/env bash
# =============================================================================
# auth-integration ハンズオン用 workspace ブートストラップ
#
# docker-compose.yml は auth-integration の「兄弟ディレクトリ」を build context
# にしている (../volta-gateway など)。このスクリプトは足りない repo を兄弟として
# clone し、`docker compose up --build` が通る状態を作る。
#
# 冪等: 既に clone 済みなら skip。何度流しても安全。
#
#   使い方:  ./setup.sh
#
# 想定レイアウト (auth-study/ = このスクリプトの2つ上):
#   auth-study/
#   ├── auth-integration/   ← このスクリプトがいる場所 (手順 + compose)
#   ├── todo-sample/        ← 対象アプリ (Java/Jetty)
#   ├── volta-gateway/      ← 唯一の入口 (Rust)
#   ├── volta-auth-proxy/   ← 認証 backend (Java)
#   └── volta-auth-console/ ← admin SPA
# =============================================================================
set -euo pipefail

GH="https://github.com/opaopa6969"

# 兄弟ディレクトリ (= auth-study/) を基準にする
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$(cd "$SCRIPT_DIR/.." && pwd)"

REPOS=(
  "todo-sample"
  "volta-gateway"
  "volta-auth-proxy"
  "volta-auth-console"
)

echo "workspace: $WS"
echo

# 旧レイアウト救済: todo/ が todo-sample の clone だったらリネームして寄せる
if [[ ! -d "$WS/todo-sample" && -d "$WS/todo" ]]; then
  if git -C "$WS/todo" remote get-url origin 2>/dev/null | grep -q "todo-sample"; then
    echo "→ todo/ は todo-sample 本体。todo-sample/ にリネーム"
    mv "$WS/todo" "$WS/todo-sample"
  fi
fi

for repo in "${REPOS[@]}"; do
  dir="$WS/$repo"
  if [[ -d "$dir/.git" ]]; then
    # 既存 repo は最新へ追従させる。clone しただけだと upstream の修正が反映されず、
    # docker compose が古いソースをビルドして「直したのに変わらない」になるため。
    # ローカル変更あり / fast-forward 不可のときは安全側で skip して警告。
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
    git -C "$dir" fetch --quiet origin "$branch" 2>/dev/null || true
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
      echo "⚠ $repo : ローカル変更あり → pull skip (手動で git stash && git pull)"
    elif git -C "$dir" merge-base --is-ancestor HEAD "origin/$branch" 2>/dev/null; then
      before="$(git -C "$dir" rev-parse --short HEAD)"
      git -C "$dir" merge --ff-only "origin/$branch" --quiet 2>/dev/null || true
      after="$(git -C "$dir" rev-parse --short HEAD)"
      if [[ "$before" == "$after" ]]; then echo "✓ $repo : 最新 ($after)"; else echo "↑ $repo : 更新 $before → $after"; fi
    else
      echo "⚠ $repo : fast-forward 不可 (分岐) → skip (手動で確認)"
    fi
  else
    echo "↓ $repo : clone"
    git clone "$GH/$repo.git" "$dir"
  fi
done

echo
echo "完了。次の手順:"
echo "  1. dev/auth-proxy-dev.env を用意   (11-本物auth-proxy起動.md)"
echo "  2. cd $SCRIPT_DIR && docker compose up --build"
echo "  3. ブラウザ http://localhost:28888/"
