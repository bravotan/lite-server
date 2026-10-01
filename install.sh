#!/bin/bash
# ~/.local/share/lite-server にインストールして launchd に登録する
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/lite-server"
LABEL="org.resourcez.lite-server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$DEST" "$HOME/Library/Logs" "$HOME/Library/LaunchAgents"

# アプリ本体（static/ は既存ファイルを消さないようマージ）
cp "$SRC/app.py" "$SRC/start-flask.sh" "$DEST/"
chmod +x "$DEST/start-flask.sh"
cp -R "$SRC/templates" "$DEST/"
mkdir -p "$DEST/static"
cp -Rn "$SRC/static/." "$DEST/static/"

# 設定（初回のみ。ユーザー名・パスワードを対話入力。環境変数 LITE_USER / LITE_PASSWORD / LITE_PORT でも指定可）
if [ ! -f "$DEST/config.env" ]; then
  USER_NAME="${LITE_USER:-}"
  PASS="${LITE_PASSWORD:-}"
  if [ -z "$USER_NAME" ]; then
    read -r -p "ユーザー名 [admin]: " USER_NAME
    USER_NAME="${USER_NAME:-admin}"
  fi
  if [ -z "$PASS" ]; then
    while :; do
      read -r -s -p "パスワード: " PASS; echo
      read -r -s -p "パスワード(確認): " PASS2; echo
      [ -n "$PASS" ] && [ "$PASS" = "$PASS2" ] && break
      echo "空、または一致しません。もう一度。"
    done
  fi
  umask 077
  {
    printf 'LITE_USER=%q\n' "$USER_NAME"
    printf 'LITE_PASSWORD=%q\n' "$PASS"
    printf 'LITE_STATIC_DIR=%q\n' "$DEST/static"
    printf 'LITE_PORT=%q\n' "${LITE_PORT:-5000}"
  } > "$DEST/config.env"
  echo "設定を保存しました: $DEST/config.env"
fi

# 旧バージョンの config.env にポート設定がなければ追記
grep -q '^LITE_PORT=' "$DEST/config.env" || echo 'LITE_PORT=5000' >> "$DEST/config.env"

# ポート確認。macOSは別プロセスが *:PORT をlistenしていても bind が成功することが
# あるため（AirPlayレシーバー等が5000を使用）、bindではなく lsof で listen 状態を見る。
# 再インストール時に自分自身を検出しないよう、先に旧サービスを止める。
PORT="$(. "$DEST/config.env"; echo "$LITE_PORT")"
case "$PORT" in
  ''|*[!0-9]*) echo "LITE_PORT が不正です: '$PORT' ($DEST/config.env)" >&2; exit 1 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "LITE_PORT は 1-65535 で指定してください: $PORT" >&2; exit 1
fi
# 旧ラベルの残骸も含めて停止する。plist が無くても label 指定の remove なら止まる。
# unload は SIGTERM 送信後すぐ戻るので、ポートが解放されるまで最大10秒待つ。
LEGACY_LABELS="com.local.flask-secret org.resourcez.flask-secret"
for L in $LABEL $LEGACY_LABELS; do
  if launchctl list "$L" >/dev/null 2>&1; then
    echo "サービス停止: $L"
    launchctl unload "$HOME/Library/LaunchAgents/$L.plist" 2>/dev/null || true
    launchctl remove "$L" 2>/dev/null || true
  fi
done
for L in $LEGACY_LABELS; do rm -f "$HOME/Library/LaunchAgents/$L.plist"; done
for _ in $(seq 20); do
  [ -z "$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null)" ] && break
  sleep 0.5
done
if USING="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null)" && [ -n "$USING" ]; then
  echo "ポート $PORT は既に使用されています:" >&2
  echo "$USING" >&2
  echo "別のポートを使う場合は $DEST/config.env の LITE_PORT を編集して再実行してください。" >&2
  echo "(macOSの場合、システム設定 > 一般 > AirDropとHandoff > AirPlayレシーバー が5000を使います)" >&2
  exit 1
fi

# 仮想環境 + Flask
# .venv があっても python が壊れている（リンク切れ・中断された作成など）ことがあるので、
# ディレクトリの有無ではなく実際に実行できるかで判定し、ダメなら作り直す。
PY="$DEST/.venv/bin/python"
if ! "$PY" -c 'import sys' >/dev/null 2>&1; then
  echo "仮想環境を作成します（python が実行できないため）"
  rm -rf "$DEST/.venv"
  uv venv "$DEST/.venv"
fi
uv pip install --python "$PY" flask
if ! "$PY" -c 'import flask' >/dev/null 2>&1; then
  echo "仮想環境で flask を import できません: $PY" >&2
  echo "--- uv: $(command -v uv) ($(uv --version 2>&1))" >&2
  ls -la "$DEST/.venv" "$DEST/.venv/bin" >&2 || true
  cat "$DEST/.venv/pyvenv.cfg" >&2 || true
  exit 1
fi

# plist 生成 & 登録
sed "s|__HOME__|$HOME|g" "$SRC/$LABEL.plist" > "$PLIST"
launchctl load "$PLIST"

# 起動確認（最大10秒待つ）
for _ in $(seq 20); do
  # 他プロセスの応答を拾わないよう 200 を確認する
  if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/login")" = "200" ]; then
    IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
    HOST="$(scutil --get LocalHostName 2>/dev/null || true)"
    echo "インストール完了: $DEST"
    echo "起動しました:"
    echo "  http://localhost:$PORT"
    [ -n "$IP" ] && echo "  http://$IP:$PORT"
    [ -n "$HOST" ] && echo "  http://$HOST.local:$PORT"
    echo "ログ: tail -f ~/Library/Logs/lite-server.log"
    exit 0
  fi
  sleep 0.5
done
echo "起動を確認できませんでした。ログを確認してください:" >&2
tail -n 20 "$HOME/Library/Logs/lite-server.log" >&2 || true
exit 1
