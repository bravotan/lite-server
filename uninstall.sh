#!/bin/bash
# 登録解除（データは ~/.local/share/lite-server に残す。完全削除は rm -rf）
PLIST="$HOME/Library/LaunchAgents/org.resourcez.flask-secret.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "解除しました。完全に消す場合: rm -rf ~/.local/share/lite-server"
