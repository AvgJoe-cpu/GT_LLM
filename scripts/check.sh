#!/usr/bin/env bash
set -euo pipefail
: "${DEBUG:=0}"; [[ "$DEBUG" == "1" ]] && set -x

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$repo_root"
# shellcheck source=/dev/null
[[ -d .venv ]] && . ".venv/bin/activate"

usage() {
  cat <<'EOF'
Usage: scripts/check.sh [--fast] [--path PATH] [--help]

Runs format (check), lint, and tests.
--fast limits to changed files where applicable.

Options:
  --fast      Only changed files for format/lint (tests still run)
  --path P    Restrict format/lint to path P (default: src)
  -h, --help  Show help
EOF
}

FAST=0
SUBPATH="src"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) FAST=1; shift ;;
    --path) SUBPATH="${2:-src}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[check] unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if (( FAST == 1 )); then
  ./scripts/format.sh --check --changed --path "$SUBPATH"
  ./scripts/lint.sh   --changed         --path "$SUBPATH"
else
  ./scripts/format.sh --check           --path "$SUBPATH"
  ./scripts/lint.sh                      --path "$SUBPATH"
fi

./scripts/test.sh
