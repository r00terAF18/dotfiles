#!/usr/bin/env bash
# Fresh-machine setup: packages -> dotfile symlinks -> GNOME. Asks before each step.
# usage: ./bootstrap.sh [--yes]
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
YES=0; [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && YES=1

step() {
	local desc="$1"; shift
	if ((!YES)); then
		read -rp "$desc? [Y/n] " ans
		[[ "${ans,,}" == n* ]] && { echo "skipped"; return 0; }
	fi
	"$@"
}

step "1/3 Install packages (pacman + AUR)" "$REPO_DIR/packages/install.sh"
step "2/3 Symlink dotfiles into \$HOME (existing files are backed up)" "$REPO_DIR/install.sh"
step "3/3 Restore GNOME settings, themes and extensions" "$REPO_DIR/gnome/setup.sh"

echo
echo "All done. See SYSTEM.md for one-time system tweaks (services etc.), then log out and back in."
