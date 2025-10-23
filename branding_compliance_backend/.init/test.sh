#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/branding-compliance-validator-214344-214532/branding_compliance_backend"
cd "$WS"
# activate venv
if [ ! -f "$WS/.venv/bin/activate" ]; then
  echo "ERROR: virtualenv not found at $WS/.venv" >&2
  exit 2
fi
. "$WS/.venv/bin/activate"
# Export .env vars if present
if [ -f "$WS/.env" ]; then set -o allexport; . "$WS/.env"; set +o allexport; fi
: "${PYTHONPATH:=}"
export PYTHONPATH="$WS:${PYTHONPATH}"
# Run Django system check; on failure provide diagnostics
if ! python manage.py check; then
  echo "ERROR: 'manage.py check' failed" >&2
  echo "--- Diagnostic: current directory and python executable ---" >&2
  printf 'cwd=%s\npython=%s\n' "$(pwd)" "$(command -v python || true)" >&2
  echo "--- Diagnostic: listing project package files ---" >&2
  ls -la "$WS/project" 2>/dev/null || true
  echo "--- Diagnostic: PYTHONPATH and DJANGO_SETTINGS_MODULE ---" >&2
  printf 'PYTHONPATH=%s\nDJANGO_SETTINGS_MODULE=%s\n' "$PYTHONPATH" "${DJANGO_SETTINGS_MODULE:-(unset)}" >&2
  echo "--- Diagnostic: attempt to import project.settings ---" >&2
  python - <<'PY'
import sys
try:
  import importlib
  m = importlib.import_module('project.settings')
  print('import_ok', getattr(m,'__name__','unknown'))
except Exception as e:
  # Print traceback and exception type/message for triage
  import traceback
  traceback.print_exc()
  print('import_failed:', type(e).__name__, e)
  sys.exit(5)
PY
  exit 4
fi
