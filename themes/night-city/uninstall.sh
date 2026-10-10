#!/usr/bin/env bash
# Undo the Night City theme from a backup made by backup.sh / install.sh.
#   1. files: remove the theme's links/copies; put back what was there before (or nothing)
#   2. btop color_theme, dconf keys, enabled/disabled extensions
#   3. VS Code / Cursor theme keys, papirus-folders colour
#   4. --remove-packages: also remove what the theme installed (packages, the EGO extension,
#      the editor theme extension, the Rajdhani font); never anything that was there before
# Uses the pre-theme backup by default (~/.night-city-backup/active), or the latest one taken
# while the theme wasn't active. Settings you changed yourself after installing are left alone.
# Backups are kept.
#
# usage: ./uninstall.sh [--dry-run] [--yes] [--backup DIR] [--remove-packages]
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"

BACKUP=''
REMOVE_PKGS=0
while (($#)); do
	case "$1" in
	-n | --dry-run) DRY_RUN=1 ;;
	-y | --yes) YES=1 ;;
	--backup) BACKUP="${2:?--backup needs a directory}"; shift ;;
	--remove-packages) REMOVE_PKGS=1 ;;
	-h | --help) sed -n '2,13p' "$0"; exit 0 ;;
	*) die "unknown option: $1" ;;
	esac
	shift
done

banner "uninstall"
((DRY_RUN)) && info "${C_CYAN}dry run: nothing will be changed${C_RESET}"
for cmd in dconf python3; do command -v "$cmd" >/dev/null || die "$cmd not found"; done

# ---- pick the backup ----
if [[ -z "$BACKUP" ]]; then
	if [[ -f "$ACTIVE_MARKER" ]]; then
		BACKUP="$BACKUP_ROOT/$(cat "$ACTIVE_MARKER")"
	else
		for d in $(ls -1d "$BACKUP_ROOT"/2* 2>/dev/null | sort -r); do
			[[ -f "$d/manifest.json" ]] || continue
			[[ "$(ncjson manifest-get "$d/manifest.json" theme_active_when_taken)" == "false" ]] && { BACKUP="$d"; break; }
		done
	fi
fi
[[ -n "$BACKUP" ]] || die "no backup found in $BACKUP_ROOT (run backup.sh or install.sh first)"
[[ "$BACKUP" == /* ]] || BACKUP="$PWD/$BACKUP"
MANIFEST="$BACKUP/manifest.json"
[[ -f "$MANIFEST" ]] || die "$MANIFEST not found"
info "restoring from ${BACKUP/#$HOME/\~} (taken $(ncjson manifest-get "$MANIFEST" created))"
[[ "$(ncjson manifest-get "$MANIFEST" theme_active_when_taken)" == "true" ]] &&
	warn "this backup was taken while Night City was active, so restoring it keeps parts of the theme"
if [[ ! -f "$ACTIVE_MARKER" ]]; then
	warn "Night City doesn't look installed (no ${ACTIVE_MARKER/#$HOME/\~}); only things that are still the theme's get undone"
fi

# Change log from every install run since this backup (install.sh writes one per run).
STATE_ROWS="$(mktemp)"
trap 'rm -f "$STATE_ROWS"' EXIT
base="$(basename "$BACKUP")"
for d in "$BACKUP_ROOT"/2*; do
	[[ -f "$d/state.tsv" && "$(basename "$d")" > "$base" || "$(basename "$d")" == "$base" ]] || continue
	[[ -f "$d/state.tsv" ]] && cat "$d/state.tsv" >>"$STATE_ROWS"
done
state() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$STATE_ROWS" | awk '!seen[$0]++'; }
state_first() { awk -F'\t' -v k="$1" '$1 == k { print $2 "\t" $3; exit }' "$STATE_ROWS"; }

confirm "Restore your previous setup from this backup?" || die "cancelled"

# ---- 1. files ----
say "Files"
declare -A SRC MODE
for entry in "${NC_FILES[@]}"; do
	IFS='|' read -r t s m <<<"$entry"
	SRC["$t"]="$s"
	MODE["$t"]="$m"
done
while IFS=$'\x1f' read -r target kind link saved parent; do
	short="${target/#$HOME/\~}"
	removed=0
	if [[ -e "$target" || -L "$target" ]]; then
		if is_ours "$target" "${SRC[$target]:-}" "${MODE[$target]:-}"; then
			run rm -f "$target"
			removed=1
		elif [[ "$kind" == absent ]]; then
			warn "$short isn't the theme's any more; left alone"
			continue
		else
			# Already back to the original? Then there's nothing to do.
			original=0
			if [[ "$kind" == symlink && -L "$target" && "$(readlink "$target")" == "$link" ]]; then
				original=1
			elif [[ "$kind" == file && -f "$target" && ! -L "$target" ]] && cmp -s "$target" "$BACKUP/$saved"; then
				original=1
			fi
			if ((original)); then
				ok "$short (already original)"
			else
				warn "$short was changed since install; left alone (original: $BACKUP/$saved)"
			fi
			continue
		fi
	fi
	case "$kind" in
	absent)
		if ((removed)); then ok "$short removed"; else ok "$short (not there, nothing to do)"; fi
		if [[ "$parent" == 0 ]] && [[ -d "$(dirname "$target")" ]]; then
			run rmdir --ignore-fail-on-non-empty "$(dirname "$target")"
		fi
		;;
	file | dir | symlink)
		run mkdir -p "$(dirname "$target")"
		run cp -a --no-dereference "$BACKUP/$saved" "$target"
		ok "$short restored${link:+ (-> $link)}"
		;;
	esac
done < <(ncjson manifest-files "$MANIFEST")

# btop: only the color_theme line (or the whole file if install.sh created it and btop never ran)
if [[ -f "$BTOP_CONF" && "$(btop_color_theme)" == "$BTOP_THEME" ]]; then
	if [[ "$(ncjson manifest-get "$MANIFEST" btop.conf_existed)" == false &&
		"$(grep -cv '^color_theme' "$BTOP_CONF")" == 0 ]]; then
		run rm -f "$BTOP_CONF"
		ok "${BTOP_CONF/#$HOME/\~} removed (install.sh created it)"
	else
		old="$(ncjson manifest-get "$MANIFEST" btop.color_theme)"
		[[ -n "$old" ]] || old="Default"
		run sed -i "s|^color_theme *=.*|color_theme = \"$old\"|" "$BTOP_CONF"
		ok "btop color_theme = \"$old\""
	fi
fi

# ---- 2. dconf ----
say "GNOME settings (dconf)"
declare -A THEME_VAL
while read -r key value; do THEME_VAL["$key"]="$value"; done < <(dconf_keys)
while IFS=$'\t' read -r key is_set value; do
	cur="$(dconf read "$key")"
	theme="${THEME_VAL[$key]:-}"
	[[ -n "$theme" ]] || continue
	if [[ "$is_set" == set ]] && same_value "$cur" "$value" || [[ "$is_set" == unset && -z "$cur" ]]; then
		ok "${key#/org/gnome/} (already original)"
	elif ! same_value "$cur" "$theme"; then
		warn "${key#/org/gnome/} is $cur now (you changed it); left alone"
	elif [[ "$is_set" == set ]]; then
		run dconf write "$key" "$value"
		ok "${key#/org/gnome/} = $value"
	else
		run dconf reset "$key"
		ok "${key#/org/gnome/} reset to default"
	fi
done < <(python3 - "$MANIFEST" <<'PY'
import json, sys
for e in json.load(open(sys.argv[1]))["dconf"]:
    if e["managed"]:
        print("\t".join([e["key"], "set" if e["set"] else "unset", e["value"] or ""]))
PY
)

en="$(dconf read /org/gnome/shell/enabled-extensions)"
dis="$(dconf read /org/gnome/shell/disabled-extensions)"
en="${en:-@as []}" dis="${dis:-@as []}"
new_en="$en" new_dis="$dis"
added="$(state ext_enabled)"
if [[ -z "$added" && ! -s "$STATE_ROWS" ]]; then
	# No change log: fall back to comparing with the backup.
	before="$(ncjson manifest-get "$MANIFEST" extensions.enabled)"
	for uuid in "${NC_EXTENSIONS[@]}"; do
		ncjson gv-has "$before" "$uuid" || added+="$uuid"$'\n'
	done
fi
while read -r uuid; do
	[[ -n "$uuid" ]] || continue
	if ncjson gv-has "$new_en" "$uuid"; then
		new_en="$(ncjson gv-remove "$new_en" "$uuid")"
		ok "disable $uuid (it wasn't enabled before)"
	fi
done <<<"$added"
while read -r uuid; do
	[[ -n "$uuid" ]] || continue
	ncjson gv-has "$new_dis" "$uuid" || new_dis="$(ncjson gv-add "$new_dis" "$uuid")"
done <<<"$(state ext_undisabled)"
[[ "$new_en" == "$en" ]] || run dconf write /org/gnome/shell/enabled-extensions "$new_en"
[[ "$new_dis" == "$dis" ]] || run dconf write /org/gnome/shell/disabled-extensions "$new_dis"
[[ "$new_en" == "$en" && "$new_dis" == "$dis" ]] && ok "extension lists unchanged"

# ---- 3. editors and folder colour ----
say "VS Code / Cursor"
for entry in "${NC_EDITORS[@]}"; do
	IFS='|' read -r name _ settings <<<"$entry"
	if [[ "$(ncjson manifest-get "$MANIFEST" "editors.$name.settings")" == "" ]]; then
		info "$name: no settings recorded, skipped"
		continue
	fi
	[[ -f "$settings" ]] || { info "$name: ${settings/#$HOME/\~} is gone, skipped"; continue; }
	cur="$(ncjson editor-read "$settings" "${EDITOR_KEYS[@]}" 2>/dev/null)" || { warn "$name: settings.json isn't plain JSON any more; restore ${EDITOR_KEYS[*]} by hand"; continue; }
	if [[ "$cur" != *"\"$EDITOR_THEME_LABEL\""* ]]; then
		ok "$name: theme keys aren't Night City's; left alone"
		continue
	fi
	run ncjson editor-restore "$settings" "$MANIFEST" "$name"
	ok "$name: ${EDITOR_KEYS[*]} restored"
done

say "Papirus folder colour"
if [[ -n "$(state papirus)" ]] && command -v papirus-folders >/dev/null; then
	orig="$(state_first papirus | cut -f1)"
	if [[ -n "$orig" ]]; then
		if confirm "Set Papirus-Dark folders back to '$orig' (asks for sudo)?"; then
			run papirus-folders -C "$orig" --theme "$PAPIRUS_THEME" || warn "papirus-folders failed"
		fi
	elif ((!REMOVE_PKGS)); then
		if confirm "Reset Papirus-Dark folders to the default colour (asks for sudo)?"; then
			run papirus-folders -D --theme "$PAPIRUS_THEME" || warn "papirus-folders failed"
		fi
	fi
else
	ok "nothing to undo"
fi

# ---- 4. things the theme installed ----
say "Installed by the theme"
pkgs=() still=()
while read -r p; do
	[[ -n "$p" ]] || continue
	pacman -Q "$p" >/dev/null 2>&1 && pkgs+=("$p")
done <<<"$(state pkg)"
egos="$(state ego)" eds="$(state editor_ext)" fonts="$(state fonts)"
if ((!REMOVE_PKGS)); then
	((${#pkgs[@]})) && info "packages: ${pkgs[*]}"
	[[ -n "$egos" ]] && info "extensions: $(echo $egos)"
	[[ -n "$eds" ]] && info "$EDITOR_EXTENSION in: $(echo $eds)"
	[[ -n "$fonts" ]] && info "fonts: ${fonts/#$HOME/\~}"
	if ((${#pkgs[@]})) || [[ -n "$egos$eds$fonts" ]]; then
		info "kept; run with --remove-packages to remove them too"
	else
		ok "nothing recorded"
	fi
else
	if ((${#pkgs[@]})); then
		if confirm "Remove ${pkgs[*]} with 'sudo pacman -Rns'?"; then
			run sudo pacman -Rns "${pkgs[@]}" || warn "pacman -Rns failed"
		fi
	fi
	while read -r uuid; do
		[[ -n "$uuid" ]] || continue
		d="$HOME/.local/share/gnome-shell/extensions/$uuid"
		[[ -d "$d" ]] || continue
		run gnome-extensions uninstall "$uuid" 2>/dev/null || run rm -rf "$d"
		ok "removed extension $uuid"
	done <<<"$egos"
	for entry in "${NC_EDITORS[@]}"; do
		IFS='|' read -r name cli _ <<<"$entry"
		grep -qx "$name" <<<"$eds" || continue
		command -v "$cli" >/dev/null || continue
		run "$cli" --uninstall-extension "$EDITOR_EXTENSION" >/dev/null 2>&1 || warn "$name: couldn't uninstall $EDITOR_EXTENSION"
		ok "$name: removed $EDITOR_EXTENSION"
	done
	if [[ -n "$fonts" && -d "$FONT_DIR" ]]; then
		run rm -rf "$FONT_DIR"
		run fc-cache -f
		ok "removed ${FONT_DIR/#$HOME/\~}"
	fi
fi

# Directories the theme created, if they're empty now
while read -r d; do
	[[ -n "$d" && -d "$d" ]] || continue
	# only empty directories are deleted; anything with files in it stays
	run find "$d" -depth -type d -empty -delete
	if [[ -d "$d" ]]; then
		ok "pruned empty dirs under ${d/#$HOME/\~} (it holds other files, so it stays)"
	else
		ok "removed empty ${d/#$HOME/\~}"
	fi
done < <(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("missing_dirs", [])))' "$MANIFEST")

# ---- done ----
run rm -f "$ACTIVE_MARKER"
say "Done"
((DRY_RUN)) && info "(dry run, nothing changed)"
cat <<MSG
  - Log out and back in so GNOME Shell drops the NightCity shell theme/extensions and the session
    forgets STARSHIP_CONFIG / MANGOHUD_CONFIGFILE. kitty: ctrl+shift+f5. Restart GTK apps.
  - Backups are kept in ${BACKUP_ROOT/#$HOME/\~} (delete them yourself when you're happy).
MSG
