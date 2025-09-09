#!/usr/bin/env bash
set -euo pipefail
: "${DEBUG:=0}"; [[ "$DEBUG" == "1" ]] && set -x

# --- config / args -----------------------------------------------------------
PY_BIN="python3"
FORCE=0
NDJSON=0
WITH_PRECOMMIT=1

usage() {
  cat <<'EOF'
Usage: scripts/setup.sh [--python PY_BIN] [--force] [--no-precommit] [--ndjson] [-h|--help]

Creates/updates .venv, upgrades pip, installs requirements, and installs pre-commit (unless disabled).

Options:
  --python PY_BIN   Python executable to use (default: python3)
  --force           Recreate .venv even if it exists
  --no-precommit    Skip installing and running pre-commit
  --ndjson          Emit machine-readable events (one JSON per line)
  -h, --help        Show this help

Env:
  DEBUG=1           Enable shell trace
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --python) PY_BIN="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --no-precommit) WITH_PRECOMMIT=0; shift ;;
    --ndjson) NDJSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# --- locate repo root & venv -------------------------------------------------
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$repo_root"
venv_dir="$repo_root/.venv"

# --- logging helpers ---------------------------------------------------------
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_emit_json() { printf '{"ts":"%s","level":"%s","event":"%s","msg":%s}\n' "$(now_iso)" "$1" "$2" "$(printf '%s' "$3" | jq -Rs .)"; }
_emit_human() { printf '%s %s %s\n' "[$(now_iso)]" "$1" "$2"; [[ -n "${3-}" ]] && printf '  %s\n' "$3"; }
emit() { if [[ $NDJSON -eq 1 ]]; then _emit_json "$@"; else _emit_human "$1" "$2" "${3-}"; fi; }
step() { emit "info"  "$1" "${2-}"; }
ok()   { emit "ok"    "$1" "${2-}"; }
warn() { emit "warn"  "$1" "${2-}"; }
fail() { emit "error" "$1" "${2-}"; }

# flush after every line so UIs see progress immediately
# (on Linux you can also run whole script via: stdbuf -oL -eL scripts/setup.sh)
export PYTHONUNBUFFERED=1

# --- error trap (ensures a final error event is sent) ------------------------
on_err() {
  local code=$?
  fail "setup.failed" "Exit code $code"
  exit "$code"
}
trap on_err ERR

# --- checks ------------------------------------------------------------------
step "setup.start" "repo_root: $repo_root"
if ! command -v "$PY_BIN" >/dev/null 2>&1; then
  fail "python.missing" "Cannot find $PY_BIN in PATH"
  exit 127
fi
ok "python.detected" "$("$PY_BIN" --version 2>/dev/null || echo 'n/a')"

# --- venv creation / activation ---------------------------------------------
if [[ $FORCE -eq 1 && -d "$venv_dir" ]]; then
  step "venv.remove" "$venv_dir"
  rm -rf "$venv_dir"
fi

if [[ ! -d "$venv_dir" ]]; then
  step "venv.create" "using $PY_BIN"
  "$PY_BIN" -m venv "$venv_dir"
else
  ok "venv.exists" "$venv_dir"
fi

# shellcheck source=/dev/null
# (activation modifies the current shell; safe to source)
step "venv.activate" "$venv_dir"
. "$venv_dir/bin/activate"

# --- pip upgrade & requirements ---------------------------------------------
step "pip.upgrade" ""
python -m pip install -U pip >/dev/null
ok "pip.version" "$(python -m pip --version)"

reqs=()
[[ -f "requirements/base.txt" ]] && reqs+=(-r requirements/base.txt)
[[ -f "requirements/dev.txt"  ]] && reqs+=(-r requirements/dev.txt)

if (( ${#reqs[@]} )); then
  step "deps.install" "${reqs[*]}"
  python -m pip install "${reqs[@]}"
  ok "deps.installed" ""
else
  warn "deps.skip" "No requirements files found"
fi

# --- pre-commit (optional) ---------------------------------------------------
if [[ $WITH_PRECOMMIT -eq 1 ]]; then
  step "precommit.ensure" ""
  if ! command -v pre-commit >/dev/null 2>&1; then
    python -m pip install pre-commit
  fi
  pre-commit install
  ok "precommit.ready" ""
else
  warn "precommit.skip" "Disabled by --no-precommit"
fi

# --- summary -----------------------------------------------------------------
ok "setup.summary" "python: $(python --version 2>/dev/null || echo 'n/a')"
ok "setup.summary" "venv:   $venv_dir"
ok "setup.done" ""
