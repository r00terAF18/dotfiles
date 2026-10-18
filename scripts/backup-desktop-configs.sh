#!/usr/bin/env bash
# Save current user settings for installed desktop environments.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_ROOT="$ROOT/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$DEST_ROOT/desktop-configs-$STAMP"
mkdir -p "$OUT"
chmod 700 "$DEST_ROOT" "$OUT"
mkdir -p "$OUT/home/.config" "$OUT/system/xdg"

copy_path() {
  local rel="$1" src="$HOME/$1" dst="$OUT/home/$1"
  if [[ -e "$src" || -L "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -a --no-dereference "$src" "$dst"
  fi
}

# Xfce, Plasma, and GTK desktop preferences.
for rel in \
  .config/xfce4 \
  .config/dconf/user \
  .config/plasma-org.kde.plasma.desktop-appletsrc \
  .config/kdeglobals .config/kwinrc .config/kwinrulesrc .config/plasmarc \
  .config/kglobalshortcutsrc .config/khotkeysrc .config/kscreenlockerrc \
  .config/ksmserverrc .config/powermanagementprofilesrc .config/kscreen \
  .config/plasma-workspace .local/share/kscreen .local/share/plasma .local/share/kwin \
  .config/gtk-3.0 .config/gtk-4.0; do
  copy_path "$rel"
done

# Human-readable GNOME settings export and extension inventory.
if command -v dconf >/dev/null 2>&1; then
  dconf dump / >"$OUT/gnome-dconf.ini" 2>"$OUT/gnome-dconf.error" || true
fi
if command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions list --user >"$OUT/gnome-extensions.txt" 2>&1 || true
  gnome-extensions list --enabled >"$OUT/gnome-enabled-extensions.txt" 2>&1 || true
fi

# Capture live Xfconf if the user's session bus permits it; XML files are copied above regardless.
if command -v xfconf-query >/dev/null 2>&1 && xfconf-query -l >"$OUT/xfconf-channels.txt" 2>"$OUT/xfconf.error"; then
  while IFS= read -r channel; do
    safe="${channel//\//_}"
    xfconf-query -c "$channel" -lv >"$OUT/xfconf-${safe}.txt" 2>>"$OUT/xfconf.error" || true
  done <"$OUT/xfconf-channels.txt"
else
  printf 'Live Xfconf query unavailable; see home/.config/xfce4/xfconf/xfce-perchannel-xml/.\n' >"$OUT/xfconf-unavailable.txt"
fi

for rel in xfce4 kwinrulesrc plasmanotifyrc; do
  src="/etc/xdg/$rel"
  [[ -e "$src" ]] && cp -a --parents "$src" "$OUT/system/xdg" || true
done

{
  printf 'created=%s\nactive_desktop=%s\nsession_desktop=%s\nsession_type=%s\n' \
    "$(date --iso-8601=seconds)" "${XDG_CURRENT_DESKTOP:-unknown}" \
    "${XDG_SESSION_DESKTOP:-unknown}" "${XDG_SESSION_TYPE:-unknown}"
  printf '\nInstalled desktop/session packages:\n'
  pacman -Q 2>/dev/null | rg -i 'gnome-shell|gnome-session|plasma-desktop|plasma-workspace|xfce4-session|xfce4-panel|xfconf' || true
} >"$OUT/manifest.txt"
pacman -Qqe >"$OUT/packages-explicit.txt"
pacman -Qq >"$OUT/packages-all.txt"
chmod -R go-rwx "$OUT"
printf 'Desktop settings backup created: %s\n' "$OUT"
printf 'Size: %s\n' "$(du -sh "$OUT" | cut -f1)"
