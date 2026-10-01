#!/bin/bash
cd "$HOME/path/to/your/flask/app"
source .venv/bin/activate  # uvで作った環境
python app.py >> "$HOME/Library/Logs/flask-secret.log" 2>&1