#!/usr/bin/env bash
set -euo pipefail
: "${DEBUG:=0}"; [[ "$DEBUG" == "1" ]] && set -x

# repo root + venv activation
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$repo_root"
# shellcheck source=/dev/null
[[ -d .venv ]] && . ".venv/bin/activate"

usage() {
  cat <<'EOF'
Usage: scripts/lint.sh [--changed] [--staged] [--path PATH] [--help]

Runs static checks (ruff) without modifying files.

Options:
  --changed   Lint files changed vs. origin/main (fallback to HEAD if main missing)
  --staged    Lint currently staged files (git index)
  --path P    Lint only under path P (default: src)
  -h, --help  Show this help

Env:
  DEBUG=1     Trace execution
EOF
}

MODE="all"
SUBPATH="src"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed) MODE="changed"; shift ;;
    --staged)  MODE="staged"; shift ;;
    --path)    SUBPATH="${2:-src}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[lint] unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# discover python files helper
filter_py() { grep -E '\.py$' || true; }

files=()
case "$MODE" in
  all)
    if [[ -d "$SUBPATH" ]]; then
      mapfile -t files < <(find "$SUBPATH" -type f -name '*.py' -print)
    fi
    ;;
  changed)
    base_ref="origin/main"
    git rev-parse --verify "$base_ref" >/dev/null 2>&1 || base_ref="HEAD~1"
    mapfile -t files < <(git diff --name-only "$base_ref"...HEAD -- "$SUBPATH" | filter_py)
    ;;
  staged)
    mapfile -t files < <(git diff --name-only --cached -- "$SUBPATH" | filter_py)
    ;;
esac

if (( ${#files[@]} == 0 )); then
  echo "[lint] no python files to lint (mode=$MODE, path=$SUBPATH)"
  exit 0
fi

echo "[lint] ruff check on ${#files[@]} files (mode=$MODE, path=$SUBPATH)"
ruff check "${files[@]}"
