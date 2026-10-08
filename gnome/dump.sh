#!/usr/bin/env bash
# Regenerate gnome/settings.ini from the live dconf database, keeping only
# curated, portable sections (no window state, history, accounts, notifications).
# usage: gnome/dump.sh [--stdout]
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OUT="$HERE/settings.ini"

dconf dump / | python3 "$HERE/filter.py" "$@" "$OUT"
