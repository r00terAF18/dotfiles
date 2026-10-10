# shellcheck shell=bash
# Shared definitions and helpers for backup.sh, install.sh and uninstall.sh.

NC_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
NC_DIST="$NC_DIR/dist"
NC_LIB="$NC_DIR/lib"
BACKUP_ROOT="${NIGHT_CITY_BACKUP_ROOT:-$HOME/.night-city-backup}"
# While the theme is installed this file holds the name of the backup taken before the
# first install, so uninstall.sh always goes back to the pre-theme state.
ACTIVE_MARKER="$BACKUP_ROOT/active"

DRY_RUN=${DRY_RUN:-0}
YES=${YES:-0}

# ---- what the theme deploys: "target|source|mode" (mode: link or copy) ----
NC_FILES=(
	"$HOME/.config/night-city|$NC_DIST|link"
	"$HOME/.config/gtk-4.0/gtk.css|$NC_DIST/gtk-4.0/gtk.css|link"
	"$HOME/.config/gtk-3.0/gtk.css|$NC_DIST/gtk-3.0/gtk.css|link"
	"$HOME/.local/share/themes/NightCity|$NC_DIST/themes/NightCity|link"
	"$HOME/.config/kitty/current-theme.conf|$NC_DIST/kitty/night-city.conf|link"
	"$HOME/.config/kitty/dark-theme.auto.conf|$NC_DIST/kitty/night-city.conf|link"
	"$HOME/.config/fish/conf.d/night-city.fish|$NC_DIST/fish/night-city.fish|link"
	"$HOME/.config/environment.d/60-night-city.conf|$NC_DIST/environment.d/60-night-city.conf|link"
	"$HOME/.config/btop/themes/night-city.theme|$NC_DIST/btop/night-city.theme|link"
	"$HOME/.config/fastfetch/config.jsonc|$NC_DIST/fastfetch/config.jsonc|link"
	"$HOME/.config/fastfetch/kiroshi.txt|$NC_DIST/fastfetch/kiroshi.txt|link"
	"$HOME/.config/fastfetch/night-city-afterlife.txt|$NC_DIST/fastfetch/night-city-afterlife.txt|link"
	"$HOME/.config/fastfetch/judy-alvarez.txt|$NC_DIST/fastfetch/judy-alvarez.txt|link"
	"$HOME/.config/fastfetch/judy-alvarez.jpg|$NC_DIR/assets/fetch/judy-alvarez.jpg|link"
	"$HOME/.config/fastfetch/night-city-kiroshi.jpg|$NC_DIR/assets/fetch/night-city-kiroshi.jpg|link"
	"$HOME/.config/neofetch/config.conf|$NC_DIST/neofetch/config.conf|link"
	"$HOME/.config/neofetch/night-city-afterlife.txt|$NC_DIST/neofetch/night-city-afterlife.txt|link"
	"$HOME/.config/neofetch/judy-alvarez.txt|$NC_DIST/neofetch/judy-alvarez.txt|link"
	"$HOME/.config/cava/config|$NC_DIST/cava/config|link"
	"$HOME/.config/burn-my-windows/profiles/night-city.conf|$NC_DIST/burn-my-windows/night-city.conf|copy"
)

# ---- packages (pacman first, then yay; never Flatpak) ----
REPO_PKGS=(adw-gtk-theme papirus-icon-theme btop cava fastfetch)
AUR_PKGS=(
	papirus-folders
	gnome-shell-extension-blur-my-shell
	gnome-shell-extension-just-perfection-desktop
)
OPTIONAL_AUR_PKGS=(ttf-orbitron) # only with --with-orbitron
BIBATA_PKG=bibata-cursor-theme-bin # only with --cursor bibata (prebuilt; ships Bibata-Modern-Amber)
CONKY_PKGS=(conky lm_sensors upower) # --with-conky; Arch's conky is built with Lua 5.4, cairo, X11 and Wayland
BOOT_PKGS=(plymouth)                 # --with-boot

# ---- downloads from pling/opendesktop (licence not stated or not ours to vendor: fetched at install time) ----
OCS_API="https://api.opendesktop.org/ocs/v1/content/data"
# Archives that can't be downloaded (the CDN is filtered on some networks) are picked up from here:
DOWNLOAD_CACHE="$HOME/.cache/night-city/downloads"
DOWNLOAD_DIRS=("$DOWNLOAD_CACHE" "$HOME/Downloads")

# ---- cursor (--cursor neon|bibata|keep) ----
ICONS_DIR="$HOME/.local/share/icons"
NEON_CURSOR_ID=2372076                    # "Cyberpunk-Neon Cursors" on pling
NEON_CURSOR_ARCHIVE='^Cyberpunk-Neon-.*\.tar\.gz$'
NEON_CURSOR_NAME="Cyberpunk-Neon"         # Name= in the shipped index.theme
BIBATA_CURSOR_NAME="Bibata-Modern-Amber"
CURSOR_NAMES=("$NEON_CURSOR_NAME" "$BIBATA_CURSOR_NAME") # any of these counts as "the theme's cursor"

# ---- conky HUD (--with-conky) ----
CONKY_ID=2349631                          # "cyberpunk-conky" (Arasaka cyberdeck HUD, MIT) on pling
CONKY_ARCHIVE='^cyberpunk-conky-.*\.zip$'
CONKY_DIR="$HOME/.local/share/night-city/conky"
CONKY_AUTOSTART="$HOME/.config/autostart/night-city-conky.desktop"

# ---- window borders (--borders glow|highlight|none) ----
GLOW_UUID="night-city-glow@amir.local"
GLOW_SRC="$NC_DIR/extensions/$GLOW_UUID"
HIGHLIGHT_UUID="highlight-focus@pimsnel.com"
HIGHLIGHT_KEYS=( # written only with --borders highlight
	"/org/gnome/shell/extensions/highlight-focus/border-color '#FCEE0A'"
	"/org/gnome/shell/extensions/highlight-focus/border-width 3"
	"/org/gnome/shell/extensions/highlight-focus/border-radius 14"
	"/org/gnome/shell/extensions/highlight-focus/disable-hiding true"
)

# ---- boot splash (--with-boot): systemd-boot has no theming, so this is Plymouth only ----
PLYMOUTH_REPO="adi1090x/plymouth-themes"  # GPL-3.0
PLYMOUTH_THEMES=(cybernetic glitch)       # both in pack_2/
PLYMOUTH_THEME_DIR=/usr/share/plymouth/themes
PLYMOUTHD_CONF=/etc/plymouth/plymouthd.conf
DRACUT_PLYMOUTH_CONF=/etc/dracut.conf.d/90-night-city-plymouth.conf
KERNEL_CMDLINE=/etc/kernel/cmdline
CMDLINE_ADD=(quiet splash)

# ---- GNOME Shell extensions ----
NC_EXTENSIONS=(
	user-theme@gnome-shell-extensions.gcampax.github.com
	blur-my-shell@aunetx
	burn-my-windows@schneegans.github.com
	just-perfection-desktop@just-perfection
)
# Installed per-user from extensions.gnome.org instead of the AUR: the AUR package
# (gnome-shell-extension-burn-my-windows 48) doesn't declare GNOME 51 yet; EGO has v49 that does.
EGO_EXTENSIONS=(burn-my-windows@schneegans.github.com)
EXT_SUBTREES=(blur-my-shell just-perfection burn-my-windows user-theme)

# ---- editors: "name|cli|settings.json" ----
NC_EDITORS=(
	"code|code|$HOME/.config/Code/User/settings.json"
	"cursor|cursor|$HOME/.config/Cursor/User/settings.json"
)
EDITOR_EXTENSION="Endormi.2077-theme"
EDITOR_THEME_LABEL="2077" # "label" in the extension's package.json
# Cursor has window.autoDetectColorScheme on, which uses preferredDarkColorTheme in dark mode.
EDITOR_KEYS=(workbench.colorTheme workbench.preferredDarkColorTheme)

# ---- fonts (Rajdhani, SIL OFL 1.1, from the google/fonts repo) ----
FONT_DIR="$HOME/.local/share/fonts/night-city"
FONT_FILES=(Rajdhani-Light.ttf Rajdhani-Regular.ttf Rajdhani-Medium.ttf Rajdhani-SemiBold.ttf Rajdhani-Bold.ttf OFL.txt)
FONT_MIRRORS=(
	https://raw.githubusercontent.com/google/fonts/main/ofl/rajdhani
	https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/rajdhani
)

PAPIRUS_THEME="Papirus-Dark"
PAPIRUS_COLOR="yellow"
BTOP_CONF="$HOME/.config/btop/btop.conf"
BTOP_THEME="night-city"
MANGOHUD_CONF="$HOME/.config/MangoHud/MangoHud.conf"
FIREFOX_THEME_URL="https://addons.mozilla.org/en-US/firefox/addon/cyberpunk-2077-ui/"
DCONF_KEYS_FILE="$NC_DIR/settings/dconf.txt"

# ---- output ----
if [[ -t 1 ]]; then
	C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_YELLOW=$'\e[1;38;2;252;238;10m' C_CYAN=$'\e[38;2;0;240;255m'
	C_RED=$'\e[1;38;2;255;0;60m' C_GREEN=$'\e[38;2;0;255;159m' C_DIM=$'\e[38;2;122;140;153m'
else
	C_RESET='' C_BOLD='' C_YELLOW='' C_CYAN='' C_RED='' C_GREEN='' C_DIM=''
fi

banner() { printf '%s// NIGHT CITY%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
say() { printf '\n%s==>%s %s%s%s\n' "$C_YELLOW" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
info() { printf '  %s\n' "$*"; }
ok() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die() { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Run a command, or only print it in dry-run mode.
run() {
	if ((DRY_RUN)); then
		local a out=''
		for a in "$@"; do
			if [[ "$a" =~ ^[A-Za-z0-9_./@:=,+%~-]+$ ]]; then
				out+=" $a"
			elif [[ "$a" != *\'* ]]; then
				out+=" '$a'"
			elif [[ "$a" != *[\"\$\`\\]* ]]; then
				out+=" \"$a\""
			else
				out+=" $(printf '%q' "$a")"
			fi
		done
		printf '  %s[dry-run]%s%s\n' "$C_DIM" "$C_RESET" "$out"
	else
		"$@"
	fi
}

# Ask a yes/no question (default no). --yes answers yes; dry-run never blocks.
confirm() {
	if ((YES)); then return 0; fi
	if ((DRY_RUN)); then
		printf '  %s[dry-run]%s would ask: %s [y/N] (assuming yes)\n' "$C_DIM" "$C_RESET" "$1"
		return 0
	fi
	local ans=''
	if [[ -r /dev/tty ]]; then
		read -rp "  ${C_CYAN}?${C_RESET} $1 [y/N] " ans </dev/tty || true
	fi
	[[ "${ans,,}" == y* ]]
}

ncjson() { python3 "$NC_LIB/ncjson.py" "$@"; }

dconf_keys() { grep -vE '^\s*(#|$)' "$DCONF_KEYS_FILE"; }

# True if the package (or something that provides it) is installed.
pkg_present() { pacman -T "$1" >/dev/null 2>&1; }

ext_dir() {
	local d
	for d in "$HOME/.local/share/gnome-shell/extensions/$1" "/usr/share/gnome-shell/extensions/$1"; do
		[[ -d "$d" ]] && { echo "$d"; return 0; }
	done
	return 1
}

# Is the deployed target the theme's own link/copy?
is_ours() {
	local target="$1" source="$2" mode="$3"
	case "$mode" in
	link) [[ -L "$target" && "$(readlink "$target")" == "$source" ]] ;;
	copy) [[ -f "$target" && ! -L "$target" ]] && cmp -s "$target" "$source" ;;
	*) return 1 ;;
	esac
}

# Compare two dconf values; numbers compare numerically (dconf prints 0.45 as 0.45000000000000001).
same_value() {
	[[ "$1" == "$2" ]] && return 0
	[[ "$1" =~ ^-?[0-9.]+$ && "$2" =~ ^-?[0-9.]+$ ]] && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 == b + 0) }'
}

# Fingerprint a file or directory tree so uninstall can detect edits made after installation.
# Includes paths, file contents, symlink targets, permissions, and ownership.
path_fingerprint() {
	python3 - "$1" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.abspath(sys.argv[1])
digest = hashlib.sha256()

def visit(path, rel):
	st = os.lstat(path)
	name = os.fsencode(rel)
	meta = f"{stat.S_IMODE(st.st_mode)}:{st.st_uid}:{st.st_gid}".encode()
	if stat.S_ISLNK(st.st_mode):
		digest.update(b"L\0" + name + b"\0" + meta + b"\0" + os.fsencode(os.readlink(path)) + b"\0")
	elif stat.S_ISDIR(st.st_mode):
		digest.update(b"D\0" + name + b"\0" + meta + b"\0")
		for child in sorted(os.listdir(path), key=os.fsencode):
			child_rel = child if rel == "." else os.path.join(rel, child)
			visit(os.path.join(path, child), child_rel)
	elif stat.S_ISREG(st.st_mode):
		digest.update(b"F\0" + name + b"\0" + meta + b"\0")
		with open(path, "rb") as stream:
			for block in iter(lambda: stream.read(1024 * 1024), b""):
				digest.update(block)
	else:
		digest.update(b"O\0" + name + b"\0" + meta + b"\0" + str(st.st_rdev).encode() + b"\0")

try:
	visit(root, ".")
except FileNotFoundError:
	print("missing")
else:
	print(digest.hexdigest())
PY
}

# Highest missing directory above a path ("" if its parent already exists), so uninstall can
# remove directories the theme created once they're empty again.
missing_root() {
	local p root=''
	p="$(dirname "$1")"
	while [[ ! -e "$p" && "$p" != / ]]; do
		root="$p"
		p="$(dirname "$p")"
	done
	echo "$root"
}

# Value the theme writes for a dconf key ("@CURSOR@" is the chosen cursor theme).
theme_value() {
	local v="$1"
	echo "${v//@CURSOR@/\'${CURSOR_NAME:-$NEON_CURSOR_NAME}\'}"
}

# Look up a pling/opendesktop download by id and file-name regex, then find or fetch it.
# Prints the path of a verified archive. Order: a local copy in DOWNLOAD_DIRS (md5-checked
# when the API is reachable), then a fresh download (the API hands out short-lived signed links).
pling_fetch() {
	local id="$1" want="$2" json='' name='' md5='' link='' d f
	json="$(curl -fsS --connect-timeout 15 --max-time 30 "$OCS_API/$id?format=json" 2>/dev/null)" || json=''
	if [[ -n "$json" ]]; then
		IFS=$'\t' read -r name md5 link < <(python3 -c '
import json, re, sys
d = json.loads(sys.stdin.read())["data"][0]
for n in range(1, 10):
    nm = d.get(f"downloadname{n}") or ""
    if nm and re.search(sys.argv[1], nm):
        print(nm, d.get(f"downloadmd5sum{n}") or "-", d.get(f"downloadlink{n}") or "-", sep="\t")
        break
' "$want" <<<"$json" 2>/dev/null) || true
	fi
	md5ok() { [[ -z "$md5" || "$md5" == - ]] || [[ "$(md5sum "$1" | cut -d' ' -f1)" == "$md5" ]]; }
	for d in "${DOWNLOAD_DIRS[@]}"; do
		[[ -d "$d" ]] || continue
		if [[ -n "$name" ]]; then
			[[ -f "$d/$name" ]] && md5ok "$d/$name" && { echo "$d/$name"; return 0; }
		else
			f="$(find "$d" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2- |
				while read -r p; do [[ "$(basename "$p")" =~ $want ]] && { echo "$p"; break; }; done)"
			[[ -n "$f" ]] && { echo "$f"; return 0; }
		fi
	done
	[[ -n "$name" && "$link" == http* ]] || return 1
	if ((DRY_RUN)); then
		echo "<$name, downloaded from pling into ${DOWNLOAD_CACHE/#$HOME/\~} (fails if the CDN is filtered)>"
		return 0
	fi
	mkdir -p "$DOWNLOAD_CACHE"
	if curl -fsSL --connect-timeout 15 --max-time 180 -o "$DOWNLOAD_CACHE/$name.part" "$link" &&
		md5ok "$DOWNLOAD_CACHE/$name.part"; then
		mv "$DOWNLOAD_CACHE/$name.part" "$DOWNLOAD_CACHE/$name"
		echo "$DOWNLOAD_CACHE/$name"
		return 0
	fi
	rm -f "$DOWNLOAD_CACHE/$name.part"
	return 1
}

# Name of the pling file (for messages), or the regex if the API isn't reachable.
pling_name() {
	curl -fsS --connect-timeout 15 --max-time 30 "$OCS_API/$1?format=json" 2>/dev/null | python3 -c '
import json, re, sys
d = json.loads(sys.stdin.read())["data"][0]
print(next((d[f"downloadname{n}"] for n in range(1, 10) if re.search(sys.argv[1], d.get(f"downloadname{n}") or "")), ""))
' "$2" 2>/dev/null || true
}

# Opt-in question for optional parts: default no, and --yes / dry-run / no terminal never opt in.
optin() {
	if ((DRY_RUN)); then
		printf '  %s[dry-run]%s would ask: %s [y/N] (assuming no; %s includes it)\n' "$C_DIM" "$C_RESET" "$1" "$2"
		return 1
	fi
	((YES)) && return 1
	[[ -r /dev/tty ]] || return 1
	local ans=''
	read -rp "  ${C_CYAN}?${C_RESET} $1 [y/N] " ans </dev/tty || true
	[[ "${ans,,}" == y* ]]
}

shell_major() { gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1; }

papirus_current_color() {
	command -v papirus-folders >/dev/null || return 0
	papirus-folders -l --theme "$PAPIRUS_THEME" 2>/dev/null | awk '$1 == ">" { print $2 }'
}

btop_color_theme() {
	[[ -f "$BTOP_CONF" ]] || return 0
	sed -n 's/^color_theme *= *"\?\([^"]*\)"\?.*/\1/p' "$BTOP_CONF" | head -1
}
