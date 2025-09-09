#!/usr/bin/env bash
set -euo pipefail
: "${DEBUG:=0}"; [[ "$DEBUG" == "1" ]] && set -x

# --- resolve repo root; avoid CWD surprises ---
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$repo_root"

usage() {
  cat <<'EOF'
Usage: scripts/setup.sh [--python PY_BIN] [--force] [--help]

Creates/updates .venv, upgrades pip, installs requirements, and installs pre-commit.
Options:
  --python PY_BIN   Python executable to use (default: python3)
  --force           Recreate .venv even if it exists
  -h, --help        Show this help
Env:
  DEBUG=1           Enable shell trace
EOF
}

# --- args ---
PY_BIN="python3"
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --python) PY_BIN="${2:-}"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[setup] unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# --- ensure python is present ---
if ! command -v "$PY_BIN" >/dev/null 2>&1; then
  echo "[setup] cannot find $PY_BIN" >&2
  exit 127
fi

# --- venv (idempotent; --force to recreate) ---
venv_dir="$repo_root/.venv"
if [[ $FORCE -eq 1 && -d "$venv_dir" ]]; then
  echo "[setup] removing existing venv ($venv_dir)"
  rm -rf "$venv_dir"
fi
if [[ ! -d "$venv_dir" ]]; then
  echo "[setup] creating venv with $PY_BIN ..."
  "$PY_BIN" -m venv "$venv_dir"
else
  echo "[setup] venv exists → $venv_dir"
fi

# shellcheck source=/dev/null
. "$venv_dir/bin/activate"

# --- pip + requirements ---
python -m pip install -U pip
reqs=()
[[ -f "requirements/base.txt" ]] && reqs+=(-r requirements/base.txt)
[[ -f "requirements/dev.txt"  ]] && reqs+=(-r requirements/dev.txt)
if (( ${#reqs[@]} )); then
  echo "[setup] installing: ${reqs[*]}"
  python -m pip install "${reqs[@]}"
else
  echo "[setup] no requirements files found (skipping install)"
fi

# --- pre-commit (in venv) ---
if ! command -v pre-commit >/dev/null 2>&1; then
  python -m pip install pre-commit
fi
pre-commit install

# --- summary ---
echo "[setup] python: $(python --version 2>/dev/null || echo 'n/a')"
echo "[setup] venv:   $venv_dir"
echo "[setup] done"
