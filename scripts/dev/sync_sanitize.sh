#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

removed_count=$(find . -type f \( -name '._*' -o -name '.DS_Store' \) -print -delete | wc -l | tr -d ' ')

echo "[sanitize] Archivos metadata eliminados: $removed_count"
echo "[sanitize] Estado git:"
git status --short
