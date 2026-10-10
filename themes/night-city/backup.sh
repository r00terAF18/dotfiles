#!/usr/bin/env bash
# Snapshot everything the Night City theme touches into ~/.night-city-backup/<timestamp>/:
#   - full `dconf dump /`, the extension subtrees, and every key from settings/dconf.txt
#   - each file the theme deploys (or a note that it didn't exist), btop.conf, editor settings
#   - installed packages/extensions/editor extensions, papirus-folders colour, MangoHud link
#   - manifest.json describing what existed, which uninstall.sh uses to restore or delete
# Read-only apart from writing the backup directory.
#
# usage: ./backup.sh [--dry-run] [--dest DIR]
#   --dry-run  collect into a temporary directory, show the summary, keep nothing
#   --dest     write to DIR instead of ~/.night-city-backup/<timestamp> (used by install.sh)
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

DEST=''
while (($#)); do
	case "$1" in
	-n | --dry-run) DRY_RUN=1 ;;
	--dest) DEST="${2:?--dest needs a directory}"; shift ;;
	-h | --help) sed -n '2,12p' "$0"; exit 0 ;;
	*) die "unknown option: $1" ;;
	esac
	shift
done

command -v dconf >/dev/null || die "dconf not found"
command -v python3 >/dev/null || die "python3 not found"

if ((DRY_RUN)); then
	OUT="$(mktemp -d)"
	trap 'rm -rf "$OUT"' EXIT
else
	if [[ -z "$DEST" ]]; then
		DEST="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
		n=1
		while [[ -e "$DEST" ]]; do DEST="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-$n"; n=$((n + 1)); done
	fi
	[[ -e "$DEST" ]] && die "$DEST already exists"
	OUT="$DEST"
	mkdir -p "$OUT"
	chmod 700 "$BACKUP_ROOT" "$OUT" 2>/dev/null || true
fi
mkdir -p "$OUT/files" "$OUT/editors"

banner "backup"
((DRY_RUN)) && info "(dry run: collecting into a temp dir, nothing is kept)" || info "-> $OUT"

misc() { printf '%s\t%s\n' "$1" "$2" >>"$OUT/misc.tsv"; }

# Copy a path into files/ (relative to $HOME, or under _root/ for anything else).
save_path() {
	local src="$1" rel
	if [[ "$src" == "$HOME/"* ]]; then rel="${src#"$HOME/"}"; else rel="_root${src}"; fi
	mkdir -p "$(dirname "$OUT/files/$rel")"
	cp -a --no-dereference "$src" "$OUT/files/$rel"
	echo "files/$rel"
}

misc created "$(date --iso-8601=seconds)"
misc theme_dir "$NC_DIR"
misc shell_version "$(shell_major || true)"
active=0
[[ -f "$ACTIVE_MARKER" ]] && active=1
[[ "$(dconf read /org/gnome/shell/extensions/user-theme/name)" == "'NightCity'" ]] && active=1
misc theme_active "$active"
((active)) && warn "Night City looks active already; this backup records the themed state (uninstall.sh still uses the pre-theme backup)"

# ---- dconf ----
say "dconf"
dconf dump / >"$OUT/dconf-full.ini"
ok "full dump: dconf-full.ini ($(wc -l <"$OUT/dconf-full.ini") lines)"
for sub in "${EXT_SUBTREES[@]}"; do
	dconf dump "/org/gnome/shell/extensions/$sub/" >"$OUT/dconf-$sub.ini"
done
ok "extension subtrees: ${EXT_SUBTREES[*]}"

record_key() { # key managed
	local v
	v="$(dconf read "$1")"
	if [[ -n "$v" ]]; then
		printf '%s\tset\t%s\t%s\n' "$1" "$v" "$2" >>"$OUT/dconf.tsv"
	else
		printf '%s\tunset\t\t%s\n' "$1" "$2" >>"$OUT/dconf.tsv"
	fi
}
nkeys=0
while read -r key _; do
	record_key "$key" 1
	nkeys=$((nkeys + 1))
done < <(dconf_keys)
# For the record only (the theme doesn't change these; uninstall leaves them alone)
for key in /org/gnome/desktop/interface/font-name /org/gnome/desktop/interface/document-font-name \
	/org/gnome/desktop/interface/monospace-font-name /org/gnome/desktop/interface/cursor-size; do
	record_key "$key" 0
done
ok "$nkeys theme keys recorded (plus font keys for reference)"

en="$(dconf read /org/gnome/shell/enabled-extensions)"
dis="$(dconf read /org/gnome/shell/disabled-extensions)"
misc enabled_extensions "${en:-@as []}"
misc disabled_extensions "${dis:-@as []}"
for uuid in "${NC_EXTENSIONS[@]}"; do
	if loc="$(ext_dir "$uuid")"; then
		printf '%s\t1\t%s\n' "$uuid" "$loc" >>"$OUT/extensions.tsv"
	else
		printf '%s\t0\t\n' "$uuid" >>"$OUT/extensions.tsv"
	fi
done
ok "enabled-extensions and extension install state"

# ---- files ----
say "Files"
for entry in "${NC_FILES[@]}"; do
	IFS='|' read -r target _ _ <<<"$entry"
	parent=0
	[[ -d "$(dirname "$target")" ]] && parent=1
	if [[ -L "$target" ]]; then
		saved="$(save_path "$target")"
		printf '%s\tsymlink\t%s\t%s\t%s\n' "$target" "$(readlink "$target")" "$saved" "$parent" >>"$OUT/files.tsv"
		ok "${target/#$HOME/\~} (symlink -> $(readlink "$target"))"
	elif [[ -d "$target" ]]; then
		saved="$(save_path "$target")"
		printf '%s\tdir\t\t%s\t%s\n' "$target" "$saved" "$parent" >>"$OUT/files.tsv"
		ok "${target/#$HOME/\~} (directory)"
	elif [[ -e "$target" ]]; then
		saved="$(save_path "$target")"
		printf '%s\tfile\t\t%s\t%s\n' "$target" "$saved" "$parent" >>"$OUT/files.tsv"
		ok "${target/#$HOME/\~} (file)"
	else
		printf '%s\tabsent\t\t\t%s\n' "$target" "$parent" >>"$OUT/files.tsv"
		info "${C_DIM}${target/#$HOME/\~} (doesn't exist)${C_RESET}"
	fi
done

if [[ -e "$BTOP_CONF" ]]; then
	save_path "$BTOP_CONF" >/dev/null
	misc btop_conf_existed 1
	misc btop_color_theme "$(btop_color_theme)"
	ok "${BTOP_CONF/#$HOME/\~} (color_theme = $(btop_color_theme))"
else
	misc btop_conf_existed 0
	info "${C_DIM}${BTOP_CONF/#$HOME/\~} (doesn't exist)${C_RESET}"
fi

misc mangohud_path "$MANGOHUD_CONF"
if [[ -L "$MANGOHUD_CONF" ]]; then
	misc mangohud_kind symlink
	misc mangohud_link "$(readlink "$MANGOHUD_CONF")"
	save_path "$MANGOHUD_CONF" >/dev/null
	ok "${MANGOHUD_CONF/#$HOME/\~} -> $(readlink "$MANGOHUD_CONF") (the theme doesn't touch it)"
elif [[ -e "$MANGOHUD_CONF" ]]; then
	misc mangohud_kind file
	save_path "$MANGOHUD_CONF" >/dev/null
	ok "${MANGOHUD_CONF/#$HOME/\~} (file; the theme doesn't touch it)"
else
	misc mangohud_kind absent
fi

if [[ -d "$FONT_DIR" ]]; then misc fonts_dir_existed 1; else misc fonts_dir_existed 0; fi

# ---- editors ----
say "Editors"
for entry in "${NC_EDITORS[@]}"; do
	IFS='|' read -r name cli settings <<<"$entry"
	has_cli=false ext=false settings_json=null
	if command -v "$cli" >/dev/null; then
		has_cli=true
		if "$cli" --list-extensions 2>/dev/null | grep -qix "$EDITOR_EXTENSION"; then ext=true; fi
	fi
	if [[ -e "$settings" ]]; then
		save_path "$settings" >/dev/null
		if ! settings_json="$(ncjson editor-read "$settings" "${EDITOR_KEYS[@]}")"; then
			settings_json=null
			warn "$name: ${settings/#$HOME/\~} isn't plain JSON; copied, but install.sh won't edit it"
		fi
	fi
	printf '{"cli": %s, "settings_path": "%s", "settings": %s, "extension_installed": %s}\n' \
		"$has_cli" "$settings" "$settings_json" "$ext" >"$OUT/editors/$name.json"
	ok "$name: cli=$has_cli, $EDITOR_EXTENSION installed=$ext, settings $([[ -e "$settings" ]] && echo saved || echo "don't exist")"
done

# ---- packages ----
say "Packages"
present_list=() missing_list=()
for p in "${REPO_PKGS[@]}" "${AUR_PKGS[@]}" "${OPTIONAL_AUR_PKGS[@]}"; do
	if pkg_present "$p"; then
		printf '%s\t1\t%s\n' "$p" "$(pacman -Q "$p" 2>/dev/null | awk '{print $2}')" >>"$OUT/packages.tsv"
		present_list+=("$p")
	else
		printf '%s\t0\t\n' "$p" >>"$OUT/packages.tsv"
		missing_list+=("$p")
	fi
done
ok "already installed: ${present_list[*]:-none}"
info "not installed:     ${missing_list[*]:-none}"

if command -v papirus-folders >/dev/null; then
	misc papirus_installed 1
	misc papirus_color "$(papirus_current_color)"
	ok "papirus-folders colour for $PAPIRUS_THEME: $(papirus_current_color)"
else
	misc papirus_installed 0
	info "papirus-folders not installed (nothing to record)"
fi

ncjson manifest-build "$OUT"
say "Done"
if ((DRY_RUN)); then
	ok "manifest would list $(wc -l <"$OUT/files.tsv") files, $(wc -l <"$OUT/dconf.tsv") dconf keys, $(wc -l <"$OUT/packages.tsv") packages"
	info "(dry run, nothing kept)"
else
	ok "backup written to $OUT"
	ok "manifest: $OUT/manifest.json"
fi
