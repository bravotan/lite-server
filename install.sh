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

# 設定（初回のみ。ユーザー名・パスワードを対話入力。環境変数 LITE_USER / LITE_PASSWORD でも指定可）
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
  } > "$DEST/config.env"
  echo "設定を保存しました: $DEST/config.env"
fi

# 仮想環境 + Flask
[ -d "$DEST/.venv" ] || uv venv "$DEST/.venv"
uv pip install --python "$DEST/.venv/bin/python" flask

# plist 生成 & 登録
sed "s|__HOME__|$HOME|g" "$SRC/$LABEL.plist" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "インストール完了: $DEST"
echo "ログ: tail -f ~/Library/Logs/lite-server.log"
