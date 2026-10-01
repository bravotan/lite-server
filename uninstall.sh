#!/bin/bash
# 登録解除（データは ~/.local/share/lite-server に残す。完全削除は rm -rf）
PLIST="$HOME/Library/LaunchAgents/org.resourcez.lite-server.plist"
LABEL="org.resourcez.lite-server"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl remove "$LABEL" 2>/dev/null || true   # plist が無くても label で停止
rm -f "$PLIST"
if launchctl list "$LABEL" >/dev/null 2>&1; then
  echo "停止できませんでした: launchctl list $LABEL を確認してください" >&2
  exit 1
fi
echo "解除しました。完全に消す場合: rm -rf ~/.local/share/lite-server"
