#!/usr/bin/env bash
# Install the Night City (Cyberpunk 2077) theme on top of the current setup.
#   0. render dist/ from palette.sh
#   1. run backup.sh first; stop if the backup fails
#   2. packages: pacman, then yay (--needed, asks before sudo, no Flatpak)
#   3. Burn My Windows from extensions.gnome.org, per user (AUR build lacks GNOME 51)
#   4. Rajdhani font into ~/.local/share/fonts/night-city (skipped gracefully if blocked)
#   5. link the configs into place (anything in the way is moved into the backup)
#   6. dconf: dark style, accent, GTK/icon/cursor/shell theme, title font, extension settings,
#      enabled extensions; btop colour theme; papirus-folders yellow
#   7. VS Code / Cursor: 2077 theme extension + workbench.colorTheme
# Every change is logged to <backup>/state.tsv, which uninstall.sh reads.
#
# usage: ./install.sh [--dry-run] [--yes] [--skip-packages] [--with-orbitron] [--no-editors]
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

SKIP_PKGS=0 WITH_ORBITRON=0 DO_EDITORS=1
for arg in "$@"; do
	case "$arg" in
	-n | --dry-run) DRY_RUN=1 ;;
	-y | --yes) YES=1 ;;
	--skip-packages) SKIP_PKGS=1 ;;
	--with-orbitron) WITH_ORBITRON=1 ;;
	--no-editors) DO_EDITORS=0 ;;
	-h | --help) sed -n '2,15p' "$0"; exit 0 ;;
	*) die "unknown option: $arg" ;;
	esac
done

banner "install"
((DRY_RUN)) && info "${C_CYAN}dry run: nothing will be changed${C_RESET}"

# ---- 0. preflight + render ----
for cmd in dconf python3 pacman curl; do command -v "$cmd" >/dev/null || die "$cmd not found"; done
[[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-}', not GNOME; continuing anyway"
SHELL_VER="$(shell_major || true)"
info "GNOME Shell ${SHELL_VER:-unknown}"

say "Rendering dist/ from palette.sh"
if ((DRY_RUN)); then
	"$NC_DIR/generate.sh" --check | sed 's/^/  /' || warn "dist/ is out of date; a real run regenerates it first"
else
	"$NC_DIR/generate.sh" | sed 's/^/  /'
fi

# ---- 1. backup ----
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TS"
say "Backup"
if ((DRY_RUN)); then
	"$HERE/backup.sh" --dry-run | sed 's/^/  /' || die "backup.sh failed; stopping before changing anything"
	STATE=/dev/null
else
	"$HERE/backup.sh" --dest "$BACKUP_DIR" | sed 's/^/  /' || die "backup.sh failed; stopping before changing anything"
	[[ -f "$BACKUP_DIR/manifest.json" ]] || die "backup has no manifest.json; stopping before changing anything"
	STATE="$BACKUP_DIR/state.tsv"
	: >"$STATE"
	if [[ -f "$ACTIVE_MARKER" ]]; then
		info "Night City was already installed; uninstall.sh will still return to $(cat "$ACTIVE_MARKER")"
	else
		echo "$TS" >"$ACTIVE_MARKER"
	fi
fi
record() { ((DRY_RUN)) || (IFS=$'\t'; printf '%s\n' "$*" >>"$STATE"); }
trap '((DRY_RUN)) || ncjson state-json "$BACKUP_DIR" 2>/dev/null || true' EXIT

# ---- 2. packages ----
say "Packages"
if ((SKIP_PKGS)); then
	info "skipped (--skip-packages)"
else
	aur=("${AUR_PKGS[@]}")
	((WITH_ORBITRON)) && aur+=("${OPTIONAL_AUR_PKGS[@]}")
	missing_repo=() missing_aur=()
	for p in "${REPO_PKGS[@]}"; do pkg_present "$p" || missing_repo+=("$p"); done
	for p in "${aur[@]}"; do pkg_present "$p" || missing_aur+=("$p"); done
	noconfirm=()
	((YES)) && noconfirm=(--noconfirm)

	if ((${#missing_repo[@]})); then
		info "official repos: ${missing_repo[*]}"
		if confirm "Install them with 'sudo pacman -S --needed'?"; then
			run sudo pacman -S --needed "${noconfirm[@]}" "${missing_repo[@]}" || warn "pacman failed; continuing with what is installed"
		else
			warn "skipped; the matching parts of the theme won't show until they're installed"
		fi
	else
		ok "official repo packages already installed: ${REPO_PKGS[*]}"
	fi

	if ((${#missing_aur[@]})); then
		info "AUR: ${missing_aur[*]}"
		if ! command -v yay >/dev/null; then
			warn "yay not found; install these yourself: ${missing_aur[*]}"
		elif confirm "Install them with 'yay -S --needed' (yay asks for sudo itself)?"; then
			run yay -S --needed "${noconfirm[@]}" "${missing_aur[@]}" || warn "yay failed; continuing with what is installed"
		else
			warn "skipped"
		fi
	else
		ok "AUR packages already installed: ${aur[*]}"
	fi

	for p in "${missing_repo[@]}" "${missing_aur[@]}"; do
		if ! ((DRY_RUN)) && pacman -Q "$p" >/dev/null 2>&1; then record pkg "$p"; fi
	done
fi

# ---- 3. extensions from extensions.gnome.org ----
say "Extensions from extensions.gnome.org"
for uuid in "${EGO_EXTENSIONS[@]}"; do
	if loc="$(ext_dir "$uuid")"; then
		ok "$uuid already installed ($loc)"
		continue
	fi
	if [[ -z "$SHELL_VER" ]]; then warn "unknown GNOME Shell version; skipping $uuid"; continue; fi
	if ((DRY_RUN)); then
		run gnome-extensions install --force "<$uuid for GNOME $SHELL_VER from extensions.gnome.org>"
		continue
	fi
	tmp="$(mktemp -d)"
	if info_json="$(curl -fsSL --max-time 30 "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VER}")" &&
		url="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["download_url"])' <<<"$info_json")" &&
		curl -fsSL --max-time 120 -o "$tmp/ext.zip" "https://extensions.gnome.org$url" &&
		gnome-extensions install --force "$tmp/ext.zip"; then
		record ego "$uuid"
		ok "$uuid installed for GNOME $SHELL_VER"
	else
		warn "couldn't install $uuid (no build for GNOME $SHELL_VER, or extensions.gnome.org unreachable)"
	fi
	rm -rf "$tmp"
done

# ---- 4. fonts ----
say "Rajdhani font (window titles)"
have_all=1
for f in "${FONT_FILES[@]}"; do [[ -s "$FONT_DIR/$f" ]] || have_all=0; done
if ((have_all)); then
	ok "already in ${FONT_DIR/#$HOME/\~}"
elif ((DRY_RUN)); then
	for f in "${FONT_FILES[@]}"; do run curl -fsSL -o "$FONT_DIR/$f" "${FONT_MIRRORS[0]}/$f"; done
	run fc-cache -f "$FONT_DIR"
else
	tmp="$(mktemp -d)"
	got=1
	for f in "${FONT_FILES[@]}"; do
		done_one=0
		for m in "${FONT_MIRRORS[@]}"; do
			if curl -fsSL --max-time 30 -o "$tmp/$f" "$m/$f" && [[ -s "$tmp/$f" ]]; then done_one=1; break; fi
		done
		((done_one)) || { got=0; break; }
	done
	if ((got)); then
		[[ -d "$FONT_DIR" ]] || record fonts "$FONT_DIR"
		mkdir -p "$FONT_DIR"
		cp "$tmp"/* "$FONT_DIR/"
		fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
		ok "installed into ${FONT_DIR/#$HOME/\~} (SIL Open Font License, OFL.txt included)"
	else
		warn "couldn't download Rajdhani (GitHub and jsDelivr may be filtered on this network)."
		warn "Titles fall back to the default font. Re-run install.sh later, or put the TTFs from"
		warn "https://fonts.google.com/specimen/Rajdhani into ${FONT_DIR/#$HOME/\~} and run fc-cache."
	fi
	rm -rf "$tmp"
fi

# ---- 5. configs ----
say "Configs"
for entry in "${NC_FILES[@]}"; do
	IFS='|' read -r target source mode <<<"$entry"
	short="${target/#$HOME/\~}"
	if is_ours "$target" "$source" "$mode"; then
		ok "$short (already in place)"
		continue
	fi
	if [[ -e "$target" || -L "$target" ]]; then
		dest="$BACKUP_DIR/displaced/${target#"$HOME/"}"
		info "moving the existing $short into the backup"
		run mkdir -p "$(dirname "$dest")"
		run mv "$target" "$dest"
		record displaced "$target" "$dest"
	fi
	run mkdir -p "$(dirname "$target")"
	if [[ "$mode" == link ]]; then
		run ln -s "$source" "$target"
		record link "$target"
		ok "$short -> ${source#"$NC_DIR/"}"
	else
		run cp "$source" "$target"
		record copy "$target"
		ok "$short (copy of ${source#"$NC_DIR/"})"
	fi
done

# btop: only the color_theme line is changed (btop rewrites btop.conf itself)
old_btop="$(btop_color_theme)"
if [[ "$old_btop" == "$BTOP_THEME" ]]; then
	ok "btop color_theme already $BTOP_THEME"
elif [[ -L "$BTOP_CONF" ]]; then
	warn "${BTOP_CONF/#$HOME/\~} is a symlink; set color_theme = \"$BTOP_THEME\" in it yourself"
else
	if [[ -f "$BTOP_CONF" ]]; then
		if grep -q '^color_theme' "$BTOP_CONF"; then
			run sed -i "s|^color_theme *=.*|color_theme = \"$BTOP_THEME\"|" "$BTOP_CONF"
		else
			((DRY_RUN)) && run echo "color_theme = \"$BTOP_THEME\"" ">>" "$BTOP_CONF" || echo "color_theme = \"$BTOP_THEME\"" >>"$BTOP_CONF"
		fi
		record btop 1 "$old_btop"
	else
		run mkdir -p "$(dirname "$BTOP_CONF")"
		((DRY_RUN)) && run echo "color_theme = \"$BTOP_THEME\"" ">" "$BTOP_CONF" || echo "color_theme = \"$BTOP_THEME\"" >"$BTOP_CONF"
		record btop 0 ""
	fi
	ok "btop color_theme = \"$BTOP_THEME\"${old_btop:+ (was \"$old_btop\")}"
fi

# ---- 6. GNOME settings ----
say "GNOME settings (dconf)"
while read -r key value; do
	cur="$(dconf read "$key")"
	if same_value "$cur" "$value"; then
		ok "${key#/org/gnome/} = $value (already)"
		continue
	fi
	run dconf write "$key" "$value"
	record dconf "$key"
	ok "${key#/org/gnome/} = $value${cur:+  (was $cur)}"
done < <(dconf_keys)

en="$(dconf read /org/gnome/shell/enabled-extensions)"
dis="$(dconf read /org/gnome/shell/disabled-extensions)"
en="${en:-@as []}" dis="${dis:-@as []}"
new_en="$en" new_dis="$dis"
for uuid in "${NC_EXTENSIONS[@]}"; do
	if ! ncjson gv-has "$new_en" "$uuid"; then
		new_en="$(ncjson gv-add "$new_en" "$uuid")"
		record ext_enabled "$uuid"
		ok "enable $uuid"
	else
		ok "$uuid already enabled"
	fi
	if ncjson gv-has "$new_dis" "$uuid"; then
		new_dis="$(ncjson gv-remove "$new_dis" "$uuid")"
		record ext_undisabled "$uuid"
	fi
	ext_dir "$uuid" >/dev/null || ((DRY_RUN)) || warn "$uuid isn't installed yet; it loads once it is (and after logging out and in)"
done
[[ "$new_en" == "$en" ]] || run dconf write /org/gnome/shell/enabled-extensions "$new_en"
[[ "$new_dis" == "$dis" ]] || run dconf write /org/gnome/shell/disabled-extensions "$new_dis"
[[ "$(dconf read /org/gnome/shell/disable-user-extensions)" == "true" ]] &&
	warn "user extensions are switched off globally (org.gnome.shell disable-user-extensions); turn them on in the Extensions app"

# papirus-folders: yellow folders in Papirus-Dark (changes files under /usr/share/icons, so it uses sudo)
if command -v papirus-folders >/dev/null || ((DRY_RUN)); then
	cur_color="$(papirus_current_color || true)"
	if [[ "$cur_color" == "$PAPIRUS_COLOR" ]]; then
		ok "Papirus folders already $PAPIRUS_COLOR"
	elif confirm "Colour Papirus-Dark folders $PAPIRUS_COLOR with papirus-folders (asks for sudo)?"; then
		if run papirus-folders -C "$PAPIRUS_COLOR" --theme "$PAPIRUS_THEME"; then
			record papirus "${cur_color:-}"
			ok "Papirus folders: $PAPIRUS_COLOR${cur_color:+ (was $cur_color)}"
		else
			warn "papirus-folders failed"
		fi
	fi
else
	warn "papirus-folders isn't installed; folders keep the default Papirus colour"
fi

# ---- 7. editors ----
say "VS Code / Cursor"
if ((!DO_EDITORS)); then
	info "skipped (--no-editors)"
else
	updates="$(python3 -c 'import json,sys; print(json.dumps({k: sys.argv[1] for k in sys.argv[2:]}))' "$EDITOR_THEME_LABEL" "${EDITOR_KEYS[@]}")"
	for entry in "${NC_EDITORS[@]}"; do
		IFS='|' read -r name cli settings <<<"$entry"
		if ! command -v "$cli" >/dev/null; then
			info "$name: '$cli' not found, skipped"
			continue
		fi
		if "$cli" --list-extensions 2>/dev/null | grep -qix "$EDITOR_EXTENSION"; then
			ok "$name: $EDITOR_EXTENSION already installed"
		elif ((DRY_RUN)); then
			run "$cli" --install-extension "$EDITOR_EXTENSION"
		elif "$cli" --install-extension "$EDITOR_EXTENSION" >/dev/null 2>&1; then
			record editor_ext "$name"
			ok "$name: installed $EDITOR_EXTENSION"
		else
			warn "$name: couldn't install $EDITOR_EXTENSION (marketplace unreachable?); install it from the Extensions view"
		fi
		if [[ -e "$settings" ]] && ! ncjson editor-read "$settings" "${EDITOR_KEYS[@]}" >/dev/null 2>&1; then
			warn "$name: ${settings/#$HOME/\~} isn't plain JSON; set \"workbench.colorTheme\": \"$EDITOR_THEME_LABEL\" yourself"
			continue
		fi
		run ncjson editor-set "$settings" "$updates"
		record editor_keys "$name"
		ok "$name: ${EDITOR_KEYS[*]} = \"$EDITOR_THEME_LABEL\""
	done
fi

# ---- done ----
say "Done"
if ((DRY_RUN)); then
	info "(dry run, nothing changed)"
else
	ok "backup and change log: $BACKUP_DIR"
fi
cat <<MSG
  Next:
  - Log out and back in: GNOME Shell loads new extensions and the NightCity shell theme, and the
    session picks up STARSHIP_CONFIG / MANGOHUD_CONFIGFILE from ~/.config/environment.d.
  - kitty: press ctrl+shift+f5 to reload. New fish shells get the colours and prompt right away.
  - Restart GTK/libadwaita apps to pick up ~/.config/gtk-4.0/gtk.css.
  - Firefox (manual): $FIREFOX_THEME_URL
  - Wallpaper isn't part of the theme. Wallhaven is filtered on this network, so use a VPN/proxy.
  - Undo everything: $HERE/uninstall.sh
MSG
