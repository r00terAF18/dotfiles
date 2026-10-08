#!/usr/bin/env python3
# Filter `dconf dump /` (stdin) down to curated sections. Used by dump.sh.
import re, sys

# section path (regex, full match) -> keys to drop (regex, full match)
KEEP = {
    r"org/gnome/Console": r"last-window-.*",
    r"org/gnome/TextEditor": r"last-.*|window-.*",
    r"org/gnome/GWeather4": None,
    r"org/gnome/desktop/app-folders(/folders/.*)?": None,
    r"org/gnome/desktop/background": None,
    r"org/gnome/desktop/screensaver": None,
    r"org/gnome/desktop/break-reminders/.*": None,
    r"org/gnome/desktop/screen-time-limits": None,
    r"org/gnome/desktop/datetime": None,
    r"org/gnome/desktop/input-sources": r"mru-sources|current",
    r"org/gnome/desktop/interface": None,
    r"org/gnome/desktop/peripherals/.*": None,
    r"org/gnome/desktop/search-providers": None,
    r"org/gnome/desktop/session": None,
    r"org/gnome/desktop/sound": None,
    r"org/gnome/desktop/wm/.*": None,
    r"org/gnome/mutter(/.*)?": None,
    r"org/gnome/nautilus/(preferences|icon-view|list-view)": r"migrated-.*",
    r"org/gnome/settings-daemon/plugins/(color|power|media-keys)": r"night-light-last-.*",
    r"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/.*": None,
    r"org/gnome/shell": r"app-picker-layout|last-selected-power-profile|welcome-dialog-last-shown-version|command-history|had-bluetooth-devices-setup",
    r"org/gnome/shell/keybindings": None,
    r"org/gnome/shell/app-switcher": None,
    r"org/gnome/shell/extensions/(all-in-one-clipboard|appindicator|dash-to-dock|dynamic-music-pill|user-theme|layout-labels|preserve-battery-health|vpn-indicator|ds4battery|screenshot-window-sizer)":
        r"playback-history|.*-history|prefs-opened|extension-version|.*-last-.*",
    r"org/gnome/tweaks": None,
}

# Settings that come from distro defaults but are part of the look; pin them.
EXTRA = {
    "org/gnome/desktop/interface": {"color-scheme": "'prefer-dark'"},
}

# Only extensions that are actually installed (stale UUIDs are dropped).
def installed_extensions():
    import os, glob
    dirs = [os.path.expanduser("~/.local/share/gnome-shell/extensions"),
            "/usr/share/gnome-shell/extensions"]
    return {os.path.basename(p) for d in dirs for p in glob.glob(d + "/*")}

text = sys.stdin.read()
sections, cur = {}, None
for line in text.splitlines():
    m = re.fullmatch(r"\[(.*)\]", line)
    if m:
        cur = m.group(1); sections[cur] = []
    elif cur and line.strip():
        sections[cur].append(line)

inst = installed_extensions()
out = []
for name, lines in sections.items():
    drop = None; keep = False
    for pat, d in KEEP.items():
        if re.fullmatch(pat, name):
            keep, drop = True, d; break
    if not keep:
        continue
    kv = {}
    for l in lines:
        k, v = l.split("=", 1)
        if drop and re.fullmatch(drop, k):
            continue
        if name == "org/gnome/shell" and k in ("enabled-extensions", "disabled-extensions"):
            uuids = re.findall(r"'([^']+)'", v)
            v = "[" + ", ".join(f"'{u}'" for u in uuids if u in inst) + "]"
        kv[k] = v
    for k, v in EXTRA.get(name, {}).items():
        kv.setdefault(k, v)
    if kv:
        out.append(f"[{name}]\n" + "\n".join(f"{k}={v}" for k, v in kv.items()) + "\n")

result = "# Curated GNOME settings. Regenerate with gnome/dump.sh, apply with gnome/setup.sh\n\n" + "\n".join(out)
if "--stdout" in sys.argv[1:-1]:
    sys.stdout.write(result)
else:
    open(sys.argv[-1], "w").write(result)
    print("wrote", sys.argv[-1])
