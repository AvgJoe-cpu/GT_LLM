#!/usr/bin/env bash
set -euo pipefail
: "${DEBUG:=0}"; [[ "$DEBUG" == "1" ]] && set -x

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$repo_root"
# shellcheck source=/dev/null
[[ -d .venv ]] && . ".venv/bin/activate"

usage() {
  cat <<'EOF'
Usage: scripts/format.sh [--check] [--changed] [--staged] [--path PATH] [--help]

Formats code with ruff format. By default writes changes; --check is read-only.

Options:
  --check     Do not write; fail if formatting is needed
  --changed   Only files changed vs. origin/main (fallback to HEAD)
  --staged    Only staged files
  --path P    Restrict to path P (default: src)
  -h, --help  Show help

Env:
  DEBUG=1     Trace execution
EOF
}

MODE="all"
SUBPATH="src"
CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)   CHECK=1; shift ;;
    --changed) MODE="changed"; shift ;;
    --staged)  MODE="staged"; shift ;;
    --path)    SUBPATH="${2:-src}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[format] unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

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
  echo "[format] no python files to process (mode=$MODE, path=$SUBPATH)"
  exit 0
fi

echo "[format] ruff format on ${#files[@]} files (mode=$MODE, check=$CHECK)"
if (( CHECK == 1 )); then
  # ruff format --check returns non-zero if changes would be made
  ruff format --check "${files[@]}"
else
  ruff format "${files[@]}"
fi
