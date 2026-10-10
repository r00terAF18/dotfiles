# shellcheck shell=bash
# Optional parts of install.sh: cursor, window borders, conky HUD, boot splash.
# Sourced by install.sh after common.sh; uses run/record/confirm and BACKUP_DIR from there.

# ---------------------------------------------------------------- cursor
# Sets CURSOR_NAME to the cursor theme to write into dconf ("" = leave the cursor alone).
install_cursor() {
	say "Cursor ($CURSOR_CHOICE)"
	case "$CURSOR_CHOICE" in
	keep)
		CURSOR_NAME=''
		ok "keeping the current cursor (--cursor keep)"
		return
		;;
	bibata)
		CURSOR_NAME="$BIBATA_CURSOR_NAME"
		cursor_available "$CURSOR_NAME" || ((DRY_RUN)) || warn "$CURSOR_NAME isn't installed ($BIBATA_PKG); the cursor falls back to Adwaita until it is"
		ok "cursor: $CURSOR_NAME"
		return
		;;
	esac
	CURSOR_NAME="$NEON_CURSOR_NAME"
	local dest="$ICONS_DIR/$NEON_CURSOR_NAME"
	if [[ -f "$dest/index.theme" && -d "$dest/cursors" ]]; then
		ok "$NEON_CURSOR_NAME already in ${dest/#$HOME/\~}"
		return
	fi
	local archive=''
	archive="$(pling_fetch "$NEON_CURSOR_ID" "$NEON_CURSOR_ARCHIVE")" || archive=''
	if [[ -z "$archive" ]]; then
		cursor_fallback "couldn't download Cyberpunk-Neon Cursors (pling's download CDN is filtered on some networks)"
		return
	fi
	info "using ${archive/#$HOME/\~}"
	if ((DRY_RUN)); then
		run tar -xzf "$archive" -C "$ICONS_DIR" "$NEON_CURSOR_NAME"
		return
	fi
	local tmp name
	tmp="$(mktemp -d)"
	if ! tar -xzf "$archive" -C "$tmp" 2>/dev/null; then
		rm -rf "$tmp"
		cursor_fallback "the cursor archive didn't unpack"
		return
	fi
	# Check what's inside: one theme directory whose index.theme names it and has cursors/
	local dir
	dir="$(find "$tmp" -mindepth 1 -maxdepth 2 -name index.theme -printf '%h\n' | head -1)"
	name="$(sed -n 's/^Name=//p' "$dir/index.theme" 2>/dev/null | head -1)"
	if [[ -z "$dir" || ! -d "$dir/cursors" || "$name" != "$NEON_CURSOR_NAME" || "$(basename "$dir")" != "$NEON_CURSOR_NAME" ]]; then
		rm -rf "$tmp"
		cursor_fallback "the archive doesn't contain the expected $NEON_CURSOR_NAME theme (found '${name:-nothing}')"
		return
	fi
	mkdir -p "$ICONS_DIR"
	record cursor_dir "$dest"
	cp -r "$dir" "$dest"
	rm -rf "$tmp"
	ok "$NEON_CURSOR_NAME installed in ${dest/#$HOME/\~} ($(find "$dest/cursors" | wc -l) cursor files, inherits $(sed -n 's/^Inherits=//p' "$dest/index.theme"))"
}

cursor_available() {
	local d
	for d in "$ICONS_DIR/$1" "$HOME/.icons/$1" "/usr/share/icons/$1"; do
		[[ -d "$d/cursors" ]] && return 0
	done
	return 1
}

cursor_fallback() {
	warn "$1."
	warn "Put $(pling_name "$NEON_CURSOR_ID" "$NEON_CURSOR_ARCHIVE" || true) (from https://www.pling.com/p/$NEON_CURSOR_ID/, e.g. via a VPN)"
	warn "into ${DOWNLOAD_CACHE/#$HOME/\~} and run install.sh again."
	if cursor_available "$BIBATA_CURSOR_NAME"; then
		CURSOR_NAME="$BIBATA_CURSOR_NAME"
		warn "using $BIBATA_CURSOR_NAME for now"
	else
		CURSOR_NAME=''
		warn "leaving the cursor as it is for now"
	fi
}

# ---------------------------------------------------------------- window borders
# Prints the extension uuid to enable (or nothing).
install_borders() {
	say "Window borders ($BORDERS)"
	case "$BORDERS" in
	none)
		info "none (pass --borders glow or --borders highlight to add one)"
		;;
	glow)
		local target="$HOME/.local/share/gnome-shell/extensions/$GLOW_UUID"
		if [[ -L "$target" && "$(readlink "$target")" == "$GLOW_SRC" ]]; then
			ok "$GLOW_UUID already linked"
		elif [[ -e "$target" || -L "$target" ]]; then
			warn "${target/#$HOME/\~} exists and isn't the theme's; left alone"
			return
		else
			run mkdir -p "$(dirname "$target")"
			run ln -s "$GLOW_SRC" "$target"
			record ext_link "$target"
			ok "${target/#$HOME/\~} -> extensions/$GLOW_UUID"
			NEEDS_RELOGIN=1
		fi
		[[ -f "$GLOW_SRC/schemas/gschemas.compiled" ]] || ((DRY_RUN)) || warn "schema not compiled (glib-compile-schemas missing?); the extension won't load"
		EXTRA_EXTENSIONS+=("$GLOW_UUID")
		;;
	highlight)
		# Installed in the extensions.gnome.org step; only its settings are written here.
		EXTRA_EXTENSIONS+=("$HIGHLIGHT_UUID")
		local line key value cur
		for line in "${HIGHLIGHT_KEYS[@]}"; do
			read -r key value <<<"$line"
			cur="$(dconf read "$key")"
			if same_value "$cur" "$value"; then
				ok "${key#/org/gnome/shell/extensions/} = $value (already)"
				continue
			fi
			record dconf_extra "$key" "$([[ -n "$cur" ]] && echo set || echo unset)" "$cur" "$value"
			run dconf write "$key" "$value"
			ok "${key#/org/gnome/shell/extensions/} = $value"
		done
		;;
	esac
}

# Does extensions.gnome.org have a build of UUID that declares GNOME Shell VERSION?
ego_supports() {
	curl -fsS --connect-timeout 15 --max-time 30 "https://extensions.gnome.org/extension-info/?uuid=$1&shell_version=$2" 2>/dev/null |
		python3 -c 'import json, sys; sys.exit(0 if sys.argv[1] in json.load(sys.stdin).get("shell_version_map", {}) else 1)' "$2" 2>/dev/null
}

# ---------------------------------------------------------------- conky
conky_params() {
	local iface tz cpu sys power w h font gpu
	iface="$(for d in /sys/class/net/*; do [[ -d "$d/wireless" ]] && basename "$d"; done | head -1)"
	[[ -n "$iface" ]] || iface="$(ip -o route show default 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
	tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
	[[ -n "$tz" ]] || tz="$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')"
	local chips
	chips="$(sensors 2>/dev/null | grep -E '^[a-z0-9_]+-[a-z0-9]+-[0-9a-f]+$')" || chips=''

	if grep -q '^coretemp-isa-0000$' <<<"$chips"; then cpu="coretemp-isa-0000|Package id 0"
	elif grep -q '^k10temp-pci-' <<<"$chips"; then cpu="$(grep -m1 '^k10temp-pci-' <<<"$chips")|Tctl"
	else cpu="coretemp-isa-0000|Package id 0"; fi
	if grep -q '^acpitz-acpi-0$' <<<"$chips"; then sys="acpitz-acpi-0|temp1"
	elif grep -q '^nvme-pci-' <<<"$chips"; then sys="$(grep -m1 '^nvme-pci-' <<<"$chips")|Composite"
	else sys="$cpu"; fi
	power="upower -i $(upower -e 2>/dev/null | grep -m1 'battery_BAT' || upower -e 2>/dev/null | grep -m1 DisplayDevice || echo /org/freedesktop/UPower/devices/DisplayDevice)"
	read -r w h < <(python3 - <<'PY' 2>/dev/null || echo "1920 1080"
import os, xml.etree.ElementTree as ET
t = ET.parse(os.path.expanduser("~/.config/monitors.xml")).getroot()
lms = t.find("configuration").findall("logicalmonitor")
lm = next((m for m in lms if (m.findtext("primary") or "") == "yes"), lms[0])
mode = lm.find("monitor/mode")
s = float(lm.findtext("scale") or 1)
print(round(int(mode.findtext("width")) / s), round(int(mode.findtext("height")) / s))
PY
)
	font="monospace"
	local families
	families="$(fc-list : family 2>/dev/null | tr ',' '\n')"
	for f in "FiraCode Nerd Font Mono" "JetBrainsMono Nerd Font Mono" "Fira Code" "JetBrains Mono"; do
		grep -qxF "$f" <<<"$families" && { font="$f"; break; }
	done
	gpu="$CONKY_DIR/gpu-load.sh"
	printf '%s\n' "width=${w:-1920}" "height=${h:-1080}" "font=$font" "iface=${iface:-wlan0}" "tz=${tz:-UTC}" \
		"cpu=$cpu" "sys=$sys" "gpu=$gpu" "power=$power"
}

install_conky() {
	say "Conky HUD (cyberpunk-conky by desdeus, MIT)"
	if ! command -v conky >/dev/null && ((!DRY_RUN)); then
		warn "conky isn't installed (package step skipped or failed); HUD skipped"
		return
	fi
	if [[ -d "$CONKY_DIR" && ! -f "$CONKY_DIR/.night-city" ]]; then
		warn "${CONKY_DIR/#$HOME/\~} exists and isn't the theme's; left alone"
		return
	fi
	local archive=''
	archive="$(pling_fetch "$CONKY_ID" "$CONKY_ARCHIVE")" || archive=''
	if [[ -z "$archive" ]]; then
		warn "couldn't download cyberpunk-conky (pling's download CDN is filtered on some networks)."
		warn "Put $(pling_name "$CONKY_ID" "$CONKY_ARCHIVE" || true) (https://www.pling.com/p/$CONKY_ID/) into ${DOWNLOAD_CACHE/#$HOME/\~} and run install.sh --with-conky again."
		return
	fi
	info "using ${archive/#$HOME/\~}"
	local -a params
	mapfile -t params < <(conky_params)
	info "adapted to this machine: ${params[*]}"
	local conf="$CONKY_DIR/cyberpunk-conky.conf"
	if ((DRY_RUN)); then
		run python3 "$NC_LIB/conky_adapt.py" "<unpacked archive>" "$CONKY_DIR" "${params[@]}"
	else
		local tmp
		tmp="$(mktemp -d)"
		python3 -m zipfile -e "$archive" "$tmp" || { rm -rf "$tmp"; warn "the conky archive didn't unpack"; return; }
		[[ -d "$CONKY_DIR" ]] || record conky_dir "$CONKY_DIR"
		if ! python3 "$NC_LIB/conky_adapt.py" "$tmp" "$CONKY_DIR" "${params[@]}" >/dev/null; then
			rm -rf "$tmp"
			warn "couldn't adapt the conky config; HUD skipped"
			return
		fi
		rm -rf "$tmp"
		touch "$CONKY_DIR/.night-city"
		ok "installed in ${CONKY_DIR/#$HOME/\~}"
	fi
	if [[ -f "$CONKY_AUTOSTART" ]] && grep -q 'night-city' "$CONKY_AUTOSTART"; then
		ok "autostart entry already there"
	else
		[[ -e "$CONKY_AUTOSTART" ]] && { warn "${CONKY_AUTOSTART/#$HOME/\~} exists and isn't the theme's; not touching it"; return; }
		run mkdir -p "$(dirname "$CONKY_AUTOSTART")"
		if ((DRY_RUN)); then
			run write "$CONKY_AUTOSTART" "(Exec=sh -c \"sleep 8; exec conky -q -c $conf\")"
		else
			record autostart "$CONKY_AUTOSTART"
			cat >"$CONKY_AUTOSTART" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Night City conky HUD
Comment=Arasaka cyberdeck HUD (cyberpunk-conky), added by the Night City theme; uninstall.sh removes it
Exec=sh -c "sleep 8; exec conky -q -c $conf"
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKTOP
		fi
		ok "autostart: ${CONKY_AUTOSTART/#$HOME/\~}"
	fi
	if pgrep -u "$USER" -f "conky.*$CONKY_DIR" >/dev/null 2>&1; then
		ok "already running"
	elif ((DRY_RUN)); then
		run conky -d -q -c "$conf"
	elif [[ -n "${DISPLAY:-}" ]]; then
		if conky -d -q -c "$conf" >/dev/null 2>&1; then
			ok "started (it draws through XWayland; see the README for what that means on GNOME)"
		else
			warn "conky didn't start; try: conky -c $conf"
		fi
	else
		info "no DISPLAY here; it starts with your next login"
	fi
}

# ---------------------------------------------------------------- boot splash
install_boot() {
	say "Boot splash (Plymouth, theme '$BOOT_THEME')"
	# This machine: systemd-boot + dracut + kernel-install-for-dracut (EndeavourOS default).
	local loader=''
	loader="$(bootctl status 2>/dev/null | sed -n 's/^ *Product: *//p' | head -1)" || true
	if [[ "$loader" != systemd-boot* ]] || ! pacman -Q dracut kernel-install-for-dracut >/dev/null 2>&1 ||
		! command -v reinstall-kernels >/dev/null || [[ ! -f "$KERNEL_CMDLINE" ]]; then
		warn "only systemd-boot + dracut + kernel-install-for-dracut (EndeavourOS's default) is automated here;"
		warn "found boot loader '${loader:-unknown}'. Boot splash skipped."
		return
	fi
	info "boot loader: $loader (no theme support, so nothing changes in the menu), initramfs: dracut"
	if ! command -v plymouth-set-default-theme >/dev/null && ((!DRY_RUN)); then
		warn "plymouth isn't installed (package step skipped or failed); boot splash skipped"
		return
	fi

	# 1. theme files (fetched from GitHub, GPL-3.0)
	local tdir="$PLYMOUTH_THEME_DIR/$BOOT_THEME" tmp=''
	if [[ -f "$tdir/$BOOT_THEME.plymouth" ]]; then
		ok "theme already in $tdir"
	elif ((DRY_RUN)); then
		run curl "<the files of pack_2/$BOOT_THEME from github.com/$PLYMOUTH_REPO (jsDelivr as fallback)>"
		run sudo cp -r "<tmp>/$BOOT_THEME" "$PLYMOUTH_THEME_DIR/"
	else
		tmp="$(mktemp -d)"
		if ! fetch_plymouth_theme "$tmp"; then
			rm -rf "$tmp"
			warn "couldn't download the $BOOT_THEME theme from GitHub/jsDelivr; boot splash skipped"
			return
		fi
	fi

	# 2. what changes
	local old new add=() t
	old="$(tr -s ' \n' ' ' <"$KERNEL_CMDLINE" | sed 's/ *$//')"
	for t in "${CMDLINE_ADD[@]}"; do
		[[ " $old " == *" $t "* ]] || add+=("$t")
	done
	new="$old${add[*]:+ ${add[*]}}"
	[[ "$new" == *root=* ]] || { warn "$KERNEL_CMDLINE has no root=; not touching it"; rm -rf "$tmp"; return; }
	info "Planned changes (all need sudo; a reboot shows the result):"
	if ((${#add[@]})); then
		info "  $KERNEL_CMDLINE: add '${add[*]}'"
		diff -u --label "$KERNEL_CMDLINE (now)" --label "$KERNEL_CMDLINE (new)" <(echo "$old") <(echo "$new") | sed 's/^/      /' || true
	else
		info "  $KERNEL_CMDLINE: already has '${CMDLINE_ADD[*]}'"
	fi
	[[ -f "$DRACUT_PLYMOUTH_CONF" ]] || info "  new $DRACUT_PLYMOUTH_CONF: add_dracutmodules+=\" plymouth \""
	info "  $PLYMOUTHD_CONF: Theme=$BOOT_THEME (plymouth-set-default-theme)"
	info "  rebuild every kernel's initramfs and boot entry: sudo reinstall-kernels"
	warn "A wrong kernel command line is the main way this can go wrong; the change above only appends words."
	warn "If a boot ever fails, pick the entry in the systemd-boot menu, press 'e', and remove 'quiet splash'."
	if ! confirm "Apply the boot splash changes?"; then
		info "skipped"
		rm -rf "$tmp"
		return
	fi

	# 3. back up, then change (each step recorded before it happens so uninstall can undo a partial run)
	local saved="$BACKUP_DIR/root"
	if ((!DRY_RUN)); then
		mkdir -p "$saved/etc/kernel" "$saved/etc/plymouth"
		cp -a "$KERNEL_CMDLINE" "$saved/etc/kernel/cmdline"
		[[ -f "$PLYMOUTHD_CONF" ]] && cp -a "$PLYMOUTHD_CONF" "$saved/etc/plymouth/plymouthd.conf"
	fi
	if [[ -n "$tmp" ]]; then
		record root_dir "$tdir"
		run sudo cp -r "$tmp/$BOOT_THEME" "$PLYMOUTH_THEME_DIR/" || { warn "copying the theme failed"; rm -rf "$tmp"; return; }
		rm -rf "$tmp"
		ok "theme installed in $tdir"
	fi
	if ((${#add[@]})); then
		record cmdline_added "${add[*]}"
		local f
		f="$(mktemp)"
		echo "$new" >"$f"
		run sudo install -m 644 "$f" "$KERNEL_CMDLINE" || { warn "writing $KERNEL_CMDLINE failed"; rm -f "$f"; return; }
		rm -f "$f"
		ok "$KERNEL_CMDLINE: added ${add[*]} (original in ${saved/#$HOME/\~}/etc/kernel/cmdline)"
	fi
	if [[ ! -f "$DRACUT_PLYMOUTH_CONF" ]]; then
		record root_created "$DRACUT_PLYMOUTH_CONF"
		local f
		f="$(mktemp)"
		printf '# Added by the Night City theme (themes/night-city/install.sh --with-boot); uninstall.sh removes it.\nadd_dracutmodules+=" plymouth "\n' >"$f"
		run sudo install -m 644 "$f" "$DRACUT_PLYMOUTH_CONF" || { warn "writing $DRACUT_PLYMOUTH_CONF failed"; rm -f "$f"; return; }
		rm -f "$f"
		ok "$DRACUT_PLYMOUTH_CONF created"
	fi
	if [[ -f "$PLYMOUTHD_CONF" ]] && ((!DRY_RUN)); then
		record root_backup "$PLYMOUTHD_CONF" "$saved/etc/plymouth/plymouthd.conf"
	else
		record root_created "$PLYMOUTHD_CONF"
	fi
	run sudo plymouth-set-default-theme "$BOOT_THEME" || warn "plymouth-set-default-theme failed"
	record initramfs 1
	info "rebuilding the initramfs for every kernel (takes a minute)..."
	if run sudo reinstall-kernels; then
		ok "boot splash ready; reboot to see it"
	else
		warn "reinstall-kernels failed. Your previous boot entries are still on the ESP; run 'sudo reinstall-kernels'"
		warn "again, or ./uninstall.sh to undo the boot changes."
	fi
}

fetch_plymouth_theme() {
	local dest="$1" list path rel ok_all=1
	list="$(curl -fsS --connect-timeout 15 --max-time 30 "https://api.github.com/repos/$PLYMOUTH_REPO/git/trees/master?recursive=1" 2>/dev/null |
		python3 -c 'import json, sys; [print(e["path"]) for e in json.load(sys.stdin)["tree"] if e["type"] == "blob" and e["path"].startswith("pack_2/" + sys.argv[1] + "/")]' "$BOOT_THEME" 2>/dev/null)" || list=''
	if [[ -z "$list" ]]; then
		list="$(curl -fsS --connect-timeout 15 --max-time 30 "https://data.jsdelivr.com/v1/packages/gh/$PLYMOUTH_REPO@master?structure=flat" 2>/dev/null |
			python3 -c 'import json, sys; [print(f["name"].lstrip("/")) for f in json.load(sys.stdin)["files"] if f["name"].lstrip("/").startswith("pack_2/" + sys.argv[1] + "/")]' "$BOOT_THEME" 2>/dev/null)" || list=''
	fi
	[[ -n "$list" ]] || return 1
	info "downloading $(wc -l <<<"$list") files of pack_2/$BOOT_THEME"
	while read -r path; do
		rel="${path#pack_2/}"
		mkdir -p "$(dirname "$dest/$rel")"
		curl -fsSL --connect-timeout 15 --max-time 60 -o "$dest/$rel" "https://raw.githubusercontent.com/$PLYMOUTH_REPO/master/$path" 2>/dev/null ||
			curl -fsSL --connect-timeout 15 --max-time 60 -o "$dest/$rel" "https://cdn.jsdelivr.net/gh/$PLYMOUTH_REPO@master/$path" 2>/dev/null ||
			{ ok_all=0; break; }
	done <<<"$list"
	((ok_all)) && [[ -f "$dest/$BOOT_THEME/$BOOT_THEME.plymouth" ]]
}
