#!/usr/bin/env bash
# Install packages from pacman.txt (repo) and aur.txt (AUR via yay). --needed, no Flatpak.
# Refresh the lists with: scripts/packages/install.sh --dump
# usage: scripts/packages/install.sh [--dry-run|--dump]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/../../packages" && pwd)"

case "${1:-}" in
--dump)
	pacman -Qqen >"$PACKAGE_DIR/pacman.txt"
	pacman -Qqem >"$PACKAGE_DIR/aur.txt"
	echo "updated pacman.txt ($(wc -l <"$PACKAGE_DIR/pacman.txt")) and aur.txt ($(wc -l <"$PACKAGE_DIR/aur.txt"))"
	exit 0
	;;
-n | --dry-run) DRY_RUN=1 ;;
"") DRY_RUN=0 ;;
*) echo "unknown option: $1" >&2; exit 1 ;;
esac

run() { if ((DRY_RUN)); then printf '[dry-run] %s\n' "$*"; else "$@"; fi; }

# Only ask pacman for packages that still exist in the sync repos.
mapfile -t repo < <(comm -12 <(pacman -Slq | sort -u) <(grep -vE '^\s*(#|$)' "$PACKAGE_DIR/pacman.txt" | sort -u))
missing="$(comm -13 <(pacman -Slq | sort -u) <(grep -vE '^\s*(#|$)' "$PACKAGE_DIR/pacman.txt" | sort -u))"
[[ -n "$missing" ]] && echo "not in repos anymore (skipped): $(echo $missing)"

((${#repo[@]})) && run sudo pacman -S --needed "${repo[@]}"

if ! command -v yay >/dev/null; then
	echo "yay not found. Install it first (EndeavourOS: sudo pacman -S yay), then re-run." >&2
	exit 1
fi
mapfile -t aur < <(grep -vE '^\s*(#|$)' "$PACKAGE_DIR/aur.txt")
((${#aur[@]})) && run yay -S --needed "${aur[@]}"
exit 0
