#!/usr/bin/env bash
# Regenerate gnome/settings.ini from the live dconf database, keeping only
# curated, portable sections (no window state, history, accounts, notifications).
# usage: scripts/gnome/export-settings.sh [--stdout]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT="$REPO_DIR/gnome/settings.ini"

dconf dump / | python3 "$SCRIPT_DIR/filter-settings.py" "$@" "$OUT"
