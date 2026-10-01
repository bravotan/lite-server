from flask import Flask, render_template, request, redirect, make_response, send_from_directory, abort
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

@app.route('/logout')
def logout():
    # サーバ側のセッションも破棄してからCookieを削除
    sessions.pop(request.cookies.get('session'), None)
    response = redirect('/login')
    response.delete_cookie('session')
    return response

def is_hidden(rel):
    return any(part.startswith('.') for part in rel.parts)

def list_dir(root, directory):
    entries = []
    for p in directory.iterdir():
        rel = p.relative_to(root)
        if p.name.startswith('.'):
            continue
        try:
            real = p.resolve()
            real.relative_to(root)  # STATIC_DIR 外を指すシンボリックリンクは除外
            st = real.stat()
        except (ValueError, OSError):
            continue
        is_dir = real.is_dir()
        entries.append({
            'name': p.name + ('/' if is_dir else ''),
            'path': rel.as_posix() + ('/' if is_dir else ''),
            'is_dir': is_dir,
            'size': None if is_dir else st.st_size,
            'mtime': datetime.fromtimestamp(st.st_mtime),
        })
    entries.sort(key=lambda e: (not e['is_dir'], e['name'].lower()))
    return entries

@app.route('/', defaults={'subpath': ''})
@app.route('/<path:subpath>')
def browse(subpath):
    if not check_session():
        return redirect('/login')
    root = STATIC_DIR.resolve()
    target = (root / subpath).resolve()
    try:
        rel = target.relative_to(root)
    except ValueError:
        abort(404)
    if is_hidden(rel):
        abort(404)
    if target.is_dir():
        if rel.parts:
            parent = '/' + (rel.parent.as_posix() + '/' if rel.parent.parts else '')
            path = '/' + rel.as_posix()
        else:
            parent, path = None, '/'
        return render_template('listing.html', path=path, parent=parent,
                               entries=list_dir(root, target))
    if target.is_file():
        return send_from_directory(root, rel.as_posix())
    abort(404)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get("LITE_PORT", 5000)), debug=False)