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
	"$HOME/.config/cava/config|$NC_DIST/cava/config|link"
	"$HOME/.config/burn-my-windows/profiles/night-city.conf|$NC_DIST/burn-my-windows/night-city.conf|copy"
)

# ---- packages (pacman first, then yay; never Flatpak) ----
REPO_PKGS=(adw-gtk-theme papirus-icon-theme btop cava fastfetch)
AUR_PKGS=(
	papirus-folders
	bibata-cursor-theme-bin # prebuilt; ships Bibata-Modern-Amber (yellow)
	gnome-shell-extension-blur-my-shell
	gnome-shell-extension-just-perfection-desktop
)
OPTIONAL_AUR_PKGS=(ttf-orbitron) # only with --with-orbitron

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
		printf '  %s[dry-run]%s' "$C_DIM" "$C_RESET"
		printf ' %q' "$@"
		printf '\n'
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

shell_major() { gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1; }

papirus_current_color() {
	command -v papirus-folders >/dev/null || return 0
	papirus-folders -l --theme "$PAPIRUS_THEME" 2>/dev/null | awk '$1 == ">" { print $2 }'
}

btop_color_theme() {
	[[ -f "$BTOP_CONF" ]] || return 0
	sed -n 's/^color_theme *= *"\?\([^"]*\)"\?.*/\1/p' "$BTOP_CONF" | head -1
}
