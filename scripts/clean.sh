#!/usr/bin/env bash
set -euo pipefail
: "${DEBUG:=0}"; [[ "$DEBUG" == "1" ]] && set -x

# ---------- repo root & safety ----------
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd -P)"
cd "$repo_root"
if [[ ! -d .git ]]; then
  echo "[clean] Refusing to run outside a git repo (no .git at $repo_root)" >&2
  exit 2
fi

usage() {
  cat <<'EOF'
Usage: scripts/clean.sh [--all] [--dry-run] [--help]

Removes common transient files and caches safely.
Defaults to a conservative clean; --all also removes notebook checkpoints and extra cruft.

Options:
  --all       Aggressive clean (adds notebook checkpoints, .DS_Store, etc.)
  --dry-run   Print what would be removed without deleting
  -h, --help  Show this help

Env:
  DEBUG=1     Enable shell trace
EOF
}

ALL=0
DRYRUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[clean] unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

rm_cmd() {
  if [[ $DRYRUN -eq 1 ]]; then
    printf '[dry-run] rm -rf %q\n' "$@"
  else
    rm -rf "$@"
  fi
}

# ---------- core sets (edit here to extend) ----------
# Safe, always-removed items (directories or files)
SAFE_PATHS=(
  ".pytest_cache" ".ruff_cache" ".mypy_cache"
  ".coverage" "coverage.xml"
  "build" "dist"
  "logs" "tmp"
)

# Find-based patterns (searched repo-wide, shallowly conservative)
safe_find_dirs=( "__pycache__" "*.egg-info" )
# Aggressive extras when --all is set
ALL_PATHS=( )
all_find_dirs=( ".ipynb_checkpoints" )
all_find_files=( ".DS_Store" )

echo "[clean] repo: $repo_root"
# ---------- do the work ----------
# 1) remove fixed safe paths
for p in "${SAFE_PATHS[@]}"; do
  [[ -e "$p" ]] && rm_cmd "$p" || true
done

# 2) find & remove safe dir patterns
for pat in "${safe_find_dirs[@]}"; do
  # -prune avoids descending into the matched dir again
  while IFS= read -r d; do rm_cmd "$d"; done < <(find . -type d -name "$pat" -prune -print)
done

# 3) aggressive extras if requested
if [[ $ALL -eq 1 ]]; then
  for p in "${ALL_PATHS[@]}"; do
    [[ -e "$p" ]] && rm_cmd "$p" || true
  done
  for pat in "${all_find_dirs[@]}"; do
    while IFS= read -r d; do rm_cmd "$d"; done < <(find . -type d -name "$pat" -prune -print)
  done
  for pf in "${all_find_files[@]}"; do
    while IFS= read -r f; do rm_cmd "$f"; done < <(find . -type f -name "$pf" -print)
  done
fi

# 4) optional hooks (modular extension; no-op if dir missing)
if [[ -d "scripts/clean.d" ]]; then
  echo "[clean] running hooks in scripts/clean.d/"
  for hook in scripts/clean.d/*.sh; do
    [[ -f "$hook" ]] || continue
    if [[ $DRYRUN -eq 1 ]]; then
      echo "[dry-run] bash $hook"
    else
      bash "$hook"
    fi
  done
fi

echo "[clean] done"
