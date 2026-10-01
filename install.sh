#!/bin/bash
# ~/.local/share/lite-server にインストールして launchd に登録する
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/lite-server"
LABEL="com.local.flask-secret"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$DEST" "$HOME/Library/Logs" "$HOME/Library/LaunchAgents"

# アプリ本体（static/ は既存ファイルを消さないようマージ）
cp "$SRC/app.py" "$SRC/start-flask.sh" "$DEST/"
chmod +x "$DEST/start-flask.sh"
cp -R "$SRC/templates" "$DEST/"
mkdir -p "$DEST/static"
cp -Rn "$SRC/static/." "$DEST/static/"

# 設定（初回のみ生成。パスワードはランダム）
if [ ! -f "$DEST/config.env" ]; then
  umask 077
  cat > "$DEST/config.env" <<CONF
LITE_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(12))')
LITE_STATIC_DIR=$DEST/static
CONF
  echo "パスワードを生成しました: $DEST/config.env"
fi

# 仮想環境 + Flask
[ -d "$DEST/.venv" ] || uv venv "$DEST/.venv"
uv pip install --python "$DEST/.venv/bin/python" flask

# plist 生成 & 登録
sed "s|__HOME__|$HOME|g" "$SRC/$LABEL.plist" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "インストール完了: $DEST"
echo "ログ: tail -f ~/Library/Logs/flask-secret.log"
