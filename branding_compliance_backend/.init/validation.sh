#!/usr/bin/env bash
set -euo pipefail
# validation - migrate, probe server, and cleanly shutdown
WS="/home/kavia/workspace/code-generation/branding-compliance-validator-214344-214532/branding_compliance_backend"
cd "$WS"
# activate venv if present
if [ -f "$WS/.venv/bin/activate" ]; then . "$WS/.venv/bin/activate"; fi
# load .env if present
if [ -f "$WS/.env" ]; then set -o allexport; . "$WS/.env"; set +o allexport; fi
export PYTHONPATH="$WS:${PYTHONPATH:-}"
LOG="$WS/server_validation.log"
PIDFILE="$WS/server_validation.pid"
# apply migrations and collectstatic
python manage.py migrate --noinput
python manage.py collectstatic --noinput >/dev/null 2>&1 || true
# start server using start helper (allow failure but expect pidfile)
bash "$WS/start" || true
# read PID
if [ -f "$PIDFILE" ]; then PID=$(cat "$PIDFILE" 2>/dev/null || true); else echo "ERROR: pid file missing" >&2; exit 4; fi
if [ -z "${PID:-}" ]; then echo "ERROR: pid empty" >&2; exit 4; fi
# poll readiness with backoff (~18s + curls timeout -> ~30s safety)
RETRIES=(1 1 2 2 4 4 8)
READY=0
for s in "${RETRIES[@]}"; do
  sleep "$s"
  if curl -sS --max-time 3 -I http://127.0.0.1:8000/ >/dev/null 2>&1; then
    READY=1
    break
  fi
done
if [ "$READY" -ne 1 ]; then
  echo "server_failed_to_start" >&2
  [ -f "$LOG" ] && echo "--- server log excerpt (up to 500 lines) ---" >&2 && tail -n 500 "$LOG" >&2 || true
  kill "${PID}" >/dev/null 2>&1 || true
  exit 5
fi
# probe HTTP status
STATUS=$(curl -sS --max-time 5 -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/ || true)
echo "server_status=$STATUS"
# shutdown gracefully (TERM then KILL fallback)
kill -TERM "${PID}" >/dev/null 2>&1 || true
for i in 1 2 3 4 5; do
  if ! kill -0 "${PID}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if kill -0 "${PID}" >/dev/null 2>&1; then
  kill -KILL "${PID}" >/dev/null 2>&1 || true
fi
sleep 1
# provide log excerpt as evidence
echo "--- server log excerpt ---"
[ -f "$LOG" ] && tail -n 200 "$LOG" || true
# cleanup
rm -f "$PIDFILE"
