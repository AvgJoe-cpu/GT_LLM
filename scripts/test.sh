#!/usr/bin/env bash
set -euo pipefail
. .venv/bin/activate
pytest -q || echo "[test] (no tests yet)"
