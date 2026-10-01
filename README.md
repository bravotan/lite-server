# Lite Server

**セットアップ：**

```bash
# uv が必要。~/.local/share/lite-server にインストールして launchd に登録
./install.sh

# パスワード確認・変更（変更後は再起動）
cat ~/.local/share/lite-server/config.env

# ログ確認
tail -f ~/Library/Logs/flask-secret.log
```

静的ファイルは `~/.local/share/lite-server/static/` に置く（再インストールしても上書きされない）。

**停止・再起動：**

```bash
launchctl stop com.local.flask-secret    # KeepAlive なので即再起動される
./uninstall.sh                           # 登録解除
```

---

**メリット：**
- Mac起動時に自動実行
- iPad側は最初1回パスワード入力 → その後1週間は再入力なし（Face ID出ない）
- ブラウザ再起動してもセッション有効
- シンプル（Flask、ログイン画面、静的提供）

