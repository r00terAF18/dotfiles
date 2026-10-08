#!/usr/bin/env bash
# Restore the GNOME desktop setup on EndeavourOS / Arch.
#   1. packages      themes, fonts, packaged extensions (pacman + yay, --needed, no Flatpak)
#   2. extensions    user extensions from extensions.gnome.org for this GNOME version
#   3. settings      dconf load gnome/settings.ini (merges; untouched keys stay as-is)
#
# usage: gnome/setup.sh [--dry-run] [--skip-packages] [--skip-extensions] [--skip-settings]
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DRY_RUN=0 DO_PKGS=1 DO_EXT=1 DO_SETTINGS=1
for arg in "$@"; do
	case "$arg" in
	-n | --dry-run) DRY_RUN=1 ;;
	--skip-packages) DO_PKGS=0 ;;
	--skip-extensions) DO_EXT=0 ;;
	--skip-settings) DO_SETTINGS=0 ;;
	-h | --help) sed -n '2,8p' "$0"; exit 0 ;;
	*) echo "unknown option: $arg" >&2; exit 1 ;;
	esac
done

say() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
run() { if ((DRY_RUN)); then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }
list() { grep -vE '^\s*(#|$)' "$1" | sed 's/\s*#.*//'; }

# ---- 1. packages ----
if ((DO_PKGS)); then
	say "Installing packages from gnome/packages.txt"
	mapfile -t repo < <(list "$HERE/packages.txt" | grep -v '^aur:' || true)
	mapfile -t aur < <(list "$HERE/packages.txt" | grep '^aur:' | sed 's/^aur://' || true)
	((${#repo[@]})) && run sudo pacman -S --needed "${repo[@]}"
	if ((${#aur[@]})); then
		if command -v yay >/dev/null; then
			run yay -S --needed "${aur[@]}"
		else
			echo "yay not found; install these AUR packages manually: ${aur[*]}" >&2
		fi
	fi
fi

# ---- 2. extensions ----
if ((DO_EXT)); then
	shell_ver="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
	say "Installing extensions for GNOME Shell $shell_ver"
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	while read -r uuid; do
		info="$(curl -fsSL --max-time 30 "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_ver}")" || {
			echo "  ! $uuid: no build for GNOME $shell_ver (or network error), skipped" >&2
			continue
		}
		url="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["download_url"])' <<<"$info")"
		ver="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])' <<<"$info")"
		echo "  - $uuid (v$ver)"
		run curl -fsSL --max-time 60 -o "$tmp/$uuid.zip" "https://extensions.gnome.org$url"
		run gnome-extensions install --force "$tmp/$uuid.zip"
	done < <(list "$HERE/extensions.txt")
fi

# ---- 3. settings ----
if ((DO_SETTINGS)); then
	say "Loading gnome/settings.ini into dconf"
	if ((DRY_RUN)); then
		grep -c '^\[' "$HERE/settings.ini" | xargs printf '  [dry-run] dconf load / < settings.ini (%s sections)\n'
	else
		dconf load / <"$HERE/settings.ini"
	fi
	# Enable each extension now too (works for ones GNOME Shell has already loaded).
	for uuid in $(sed -n "s/^enabled-extensions=\[\(.*\)\]/\1/p" "$HERE/settings.ini" | tr -d "' " | tr ',' ' '); do
		run gnome-extensions enable "$uuid" 2>/dev/null || true
	done
fi

say "Done. Log out and back in so GNOME Shell loads newly installed extensions and themes."
