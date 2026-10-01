from flask import Flask, render_template, request, redirect, make_response, send_from_directory
import os
import secrets
from datetime import datetime, timedelta
from pathlib import Path

app = Flask(__name__)
USER = os.environ["LITE_USER"]
PASSWORD = os.environ["LITE_PASSWORD"]
STATIC_DIR = Path(os.environ.get("LITE_STATIC_DIR", Path(__file__).parent / "static"))  # 静的ファイルディレクトリ
sessions = {}  # {token: 有効期限}

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user = request.form.get('username', '')
        pwd = request.form.get('password', '')
        # 両方評価してタイミング差を出さない
        ok_user = secrets.compare_digest(user.encode(), USER.encode())
        ok_pwd = secrets.compare_digest(pwd.encode(), PASSWORD.encode())
        if ok_user and ok_pwd:
            token = secrets.token_hex(16)
            sessions[token] = datetime.now() + timedelta(days=7)
            response = redirect('/')
            response.set_cookie('session', token, max_age=7*24*3600)
            return response
        return render_template('login.html', error="Wrong username or password"), 401
    return render_template('login.html')

def check_session():
    token = request.cookies.get('session')
    if token and token in sessions:
        if sessions[token] > datetime.now():
            return True
    return False

@app.route('/')
def index():
    if not check_session():
        return redirect('/login')
    # 静的ファイル一覧とか、直接ファイル提供
    return send_from_directory(STATIC_DIR, "index.html")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)