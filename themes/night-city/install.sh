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
#   optional: Cyberpunk-Neon cursor (default), window border glow, conky HUD, Plymouth boot splash
# Every change is logged to <backup>/state.tsv, which uninstall.sh reads.
#
# usage: ./install.sh [--dry-run] [--yes] [--skip-packages] [--with-orbitron] [--no-editors] [--reapply]
#                     [--cursor neon|bibata|keep] [--icons papirus] [--borders [glow|highlight|none]]
#                     [--with-conky] [--with-boot [--boot-theme cybernetic|glitch]]
#        ./install.sh --refresh [--dry-run]
#   --cursor     neon (default): Cyberpunk-Neon Cursors from pling, downloaded at install time;
#                bibata: Bibata-Modern-Amber from the AUR; keep: leave the cursor alone
#   --borders    glow (default when given without a value): the theme's own Night City Glow
#                extension (animated neon border); highlight: Highlight Focus from EGO (static)
#   --with-conky Arasaka cyberdeck HUD (conky), adapted to this machine, autostarted
#   --with-boot  Plymouth splash (cybernetic or glitch) via dracut; edits /etc/kernel/cmdline (asks)
#   --refresh    only re-render dist/ and reload the NightCity shell theme (no packages, no dconf)
#   --reapply    on a re-install, also reset GNOME settings you changed after installing
#                (by default those are left as you set them)
# Without these flags you're asked about the border, the HUD and the boot splash (default no).
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"
# shellcheck source=lib/optional.sh
source "$HERE/lib/optional.sh"

SKIP_PKGS=0 WITH_ORBITRON=0 DO_EDITORS=1 REFRESH=0 REAPPLY=0
CURSOR_CHOICE=neon ICONS=papirus BORDERS='' WITH_CONKY='' WITH_BOOT='' BOOT_THEME="${PLYMOUTH_THEMES[0]}"
while (($#)); do
	case "$1" in
	-n | --dry-run) DRY_RUN=1 ;;
	-y | --yes) YES=1 ;;
	--skip-packages) SKIP_PKGS=1 ;;
	--with-orbitron) WITH_ORBITRON=1 ;;
	--no-editors) DO_EDITORS=0 ;;
	--cursor) CURSOR_CHOICE="${2:-}"; shift ;;
	--cursor=*) CURSOR_CHOICE="${1#*=}" ;;
	--icons) ICONS="${2:-}"; shift ;;
	--icons=*) ICONS="${1#*=}" ;;
	--borders)
		if [[ "${2:-}" =~ ^(glow|highlight|none)$ ]]; then BORDERS="$2"; shift; else BORDERS=glow; fi ;;
	--borders=*) BORDERS="${1#*=}" ;;
	--with-conky) WITH_CONKY=1 ;;
	--with-boot) WITH_BOOT=1 ;;
	--boot-theme) BOOT_THEME="${2:-}"; shift ;;
	--boot-theme=*) BOOT_THEME="${1#*=}" ;;
	--refresh) REFRESH=1 ;;
	--reapply) REAPPLY=1 ;;
	-h | --help) sed -n '2,32p' "$0"; exit 0 ;;
	*) die "unknown option: $1" ;;
	esac
	shift
done
[[ "$CURSOR_CHOICE" =~ ^(neon|bibata|keep)$ ]] || die "--cursor must be neon, bibata or keep"
[[ -z "$BORDERS" || "$BORDERS" =~ ^(glow|highlight|none)$ ]] || die "--borders must be glow, highlight or none"
[[ " ${PLYMOUTH_THEMES[*]} " == *" $BOOT_THEME "* ]] || die "--boot-theme must be one of: ${PLYMOUTH_THEMES[*]}"
case "$ICONS" in
papirus) ;;
daemon)
	die "--icons daemon: pling 2213960 ('Daemon-2.0 Icon Theme') only ships daemon-2.0.zip, which is a Kvantum
       (Qt widget) theme (daemon-2.0.kvconfig + .svg), not an icon theme, so there's nothing to install
       as icons. Papirus-Dark with yellow folders stays the icon theme." ;;
*) die "--icons must be papirus" ;;
esac

banner "$( ((REFRESH)) && echo refresh || echo install)"
((DRY_RUN)) && info "${C_CYAN}dry run: nothing will be changed${C_RESET}"

# ---- --refresh: re-render and reload, nothing else ----
if ((REFRESH)); then
	say "Rendering dist/ from palette.sh"
	if ((DRY_RUN)); then
		"$NC_DIR/generate.sh" --check | sed 's/^/  /' || info "a real run would regenerate dist/"
	else
		"$NC_DIR/generate.sh" | sed 's/^/  /'
	fi
	say "Deployed files"
	for entry in "${NC_FILES[@]}"; do
		IFS='|' read -r target source mode <<<"$entry"
		short="${target/#$HOME/\~}"
		if is_ours "$target" "$source" "$mode"; then
			ok "$short"
		elif [[ "$mode" == copy && -f "$target" ]]; then
			info "$short is a copy that differs from dist/ (edited by its app?); left alone"
		else
			warn "$short isn't the theme's (not installed, or changed); run install.sh to deploy it"
		fi
	done
	glow_link="$HOME/.local/share/gnome-shell/extensions/$GLOW_UUID"
	[[ -L "$glow_link" ]] && ok "${glow_link/#$HOME/\~} (schema recompiled by generate.sh; the extension rereads settings live)"
	say "GNOME Shell theme"
	name="$(dconf read /org/gnome/shell/extensions/user-theme/name)"
	if [[ "$name" == "'NightCity'" ]]; then
		# user-theme reloads the stylesheet when the name changes; flip it off and back on.
		run dconf write /org/gnome/shell/extensions/user-theme/name "''"
		((DRY_RUN)) || sleep 1
		run dconf write /org/gnome/shell/extensions/user-theme/name "'NightCity'"
		ok "NightCity shell theme reloaded"
	else
		info "user-theme name is ${name:-unset}, not 'NightCity'; nothing to reload"
	fi
	info "GTK apps pick up the new gtk.css when they're restarted."
	exit 0
fi

# ---- optional parts: ask (default no) unless chosen on the command line ----
if [[ -z "$BORDERS" ]]; then
	if optin "Add the animated neon border around the focused window (Night City Glow extension)?" "--borders glow"; then BORDERS=glow; else BORDERS=none; fi
fi
if [[ -z "$WITH_CONKY" ]]; then
	if optin "Add the conky HUD (Arasaka cyberdeck, starts at login)?" "--with-conky"; then WITH_CONKY=1; else WITH_CONKY=0; fi
fi
if [[ -z "$WITH_BOOT" ]]; then
	if optin "Add a Plymouth boot splash (needs sudo, edits the kernel command line, reboot to see it)?" "--with-boot"; then WITH_BOOT=1; else WITH_BOOT=0; fi
fi
EXTRA_EXTENSIONS=() NEEDS_RELOGIN=0
CURSOR_NAME=''

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
	repo=("${REPO_PKGS[@]}")
	((WITH_CONKY)) && repo+=("${CONKY_PKGS[@]}")
	((WITH_BOOT)) && repo+=("${BOOT_PKGS[@]}")
	aur=("${AUR_PKGS[@]}")
	((WITH_ORBITRON)) && aur+=("${OPTIONAL_AUR_PKGS[@]}")
	[[ "$CURSOR_CHOICE" == bibata ]] && aur+=("$BIBATA_PKG")
	missing_repo=() missing_aur=()
	for p in "${repo[@]}"; do pkg_present "$p" || missing_repo+=("$p"); done
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
		ok "official repo packages already installed: ${repo[*]}"
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
ego=("${EGO_EXTENSIONS[@]}")
if [[ "$BORDERS" == highlight ]]; then
	if [[ -n "$SHELL_VER" ]] && ego_supports "$HIGHLIGHT_UUID" "$SHELL_VER"; then
		ego+=("$HIGHLIGHT_UUID")
	else
		warn "Highlight Focus has no build for GNOME ${SHELL_VER:-?} on extensions.gnome.org (newest declares 49;"
		warn "upstream main declares 50), so GNOME would refuse to load it. Use --borders glow instead."
		BORDERS=none
	fi
fi
for uuid in "${ego[@]}"; do
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
		if [[ "$uuid" == "$HIGHLIGHT_UUID" ]]; then record ego_border "$uuid"; else record ego "$uuid"; fi
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

# ---- cursor and window borders (before dconf, which needs their names) ----
install_cursor
install_borders

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
# Keys an earlier install already set: if they differ now, you changed them; keep that.
declare -A EARLIER
if [[ -f "$ACTIVE_MARKER" ]]; then
	for d in "$BACKUP_ROOT"/2*; do
		[[ -f "$d/state.tsv" && "$d" != "$BACKUP_DIR" ]] || continue
		[[ "$(basename "$d")" < "$(cat "$ACTIVE_MARKER")" ]] && continue
		while IFS=$'\t' read -r kind key _; do
			[[ "$kind" == dconf ]] && EARLIER["$key"]=1
		done <"$d/state.tsv"
	done
fi
while read -r key value; do
	if [[ "$value" == *@CURSOR@* && -z "$CURSOR_NAME" ]]; then
		info "${key#/org/gnome/} left as $(dconf read "$key")"
		continue
	fi
	is_cursor=0
	[[ "$value" == *@CURSOR@* ]] && is_cursor=1
	value="$(theme_value "$value")"
	cur="$(dconf read "$key")"
	if same_value "$cur" "$value"; then
		ok "${key#/org/gnome/} = $value (already)"
		continue
	fi
	if ((!REAPPLY)) && [[ -n "${EARLIER[$key]:-}" ]]; then
		# A cursor switch between the theme's own cursors isn't a change of yours.
		theirs=1
		if ((is_cursor)); then
			for c in "${CURSOR_NAMES[@]}"; do [[ "$cur" == "'$c'" ]] && theirs=0; done
		fi
		if ((theirs)); then
			info "${key#/org/gnome/} is ${cur:-unset} (changed after install); kept. --reapply resets it to $value"
			continue
		fi
	fi
	run dconf write "$key" "$value"
	record dconf "$key" "$value"
	ok "${key#/org/gnome/} = $value${cur:+  (was $cur)}"
done < <(dconf_keys)

en="$(dconf read /org/gnome/shell/enabled-extensions)"
dis="$(dconf read /org/gnome/shell/disabled-extensions)"
en="${en:-@as []}" dis="${dis:-@as []}"
new_en="$en" new_dis="$dis"
for uuid in "${NC_EXTENSIONS[@]}" "${EXTRA_EXTENSIONS[@]}"; do
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

# ---- optional: conky HUD and boot splash ----
((WITH_CONKY)) && install_conky
((WITH_BOOT)) && install_boot

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
if ((NEEDS_RELOGIN)); then
	warn "Night City Glow was just added. GNOME on Wayland only discovers new extensions at login:"
	warn "log out and back in, then it's enabled automatically. Tweak it with e.g."
	warn "  gsettings --schemadir $GLOW_SRC/schemas set org.gnome.shell.extensions.night-city-glow mode rainbow"
fi
((WITH_BOOT)) && info "  - Boot splash: reboot to see it. Undo with uninstall.sh (asks before touching /etc)."
true
