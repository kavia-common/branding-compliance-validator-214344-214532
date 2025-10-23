#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/branding-compliance-validator-214344-214532/branding_compliance_backend"
cd "$WS"
. "$WS/.venv/bin/activate"
if [ -f "$WS/.env" ]; then set -o allexport; . "$WS/.env"; set +o allexport; fi
export PYTHONPATH="$WS:${PYTHONPATH:-}"
LOG="$WS/server_validation.log"
: >"$LOG"
# start server in background and record pid
PYTHONUNBUFFERED=1 python manage.py runserver 0.0.0.0:8000 >"$LOG" 2>&1 &
echo $! > "$WS/server_validation.pid"
# quick sanity: ensure PID is running
sleep 0.5
PID=$(cat "$WS/server_validation.pid" 2>/dev/null || true)
if [ -z "$PID" ] || ! kill -0 "$PID" >/dev/null 2>&1; then echo "ERROR: server failed to start, see $LOG" >&2; [ -f "$LOG" ] && tail -n 200 "$LOG" >&2 || true; exit 3; fi
