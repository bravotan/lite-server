#!/bin/bash
cd "$(dirname "$0")"
set -a; source config.env; set +a
exec .venv/bin/python app.py >> "$HOME/Library/Logs/lite-server.log" 2>&1
