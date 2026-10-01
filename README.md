# Lite Server

**セットアップ：**

```bash
# 1. Flask + セッション周りをinstall（uv使用）
uv pip install flask

# 2. plistを登録
launchctl load ~/Library/LaunchAgents/com.local.flask-secret.plist

# 3. 起動確認
launchctl start com.local.flask-secret

# 4. ログ確認
tail -f ~/Library/Logs/flask-secret.log
```

**停止・再起動：**

```bash
launchctl stop com.local.flask-secret
launchctl unload ~/Library/LaunchAgents/com.local.flask-secret.plist
```

---

**メリット：**
- Mac起動時に自動実行
- iPad側は最初1回パスワード入力 → その後1週間は再入力なし（Face ID出ない）
- ブラウザ再起動してもセッション有効
- シンプル（Flask、ログイン画面、静的提供）

