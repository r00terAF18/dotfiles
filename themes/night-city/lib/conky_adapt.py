#!/usr/bin/env python3
"""Adapt desdeus' cyberpunk-conky (MIT) to this machine and the Night City palette.

usage: conky_adapt.py SRC_DIR DEST_DIR key=value...
keys: width height font iface tz cpu sys gpu power

Only the documented template values and window size are changed, plus:
  - out_to_x = true / out_to_wayland = false: GNOME's compositor has no wlr-layer-shell, so
    conky's Wayland output can't run there; it draws through XWayland instead.
  - neofetch (not in Arch's repos any more) -> fastfetch with the same "Key: value" lines.
  - the two HUD colours nudged to the palette (cyan 00FFFF -> 00F0FF, red EA4A5A -> FF003C).
"""
import os
import re
import shutil
import sys

src, dest = sys.argv[1], sys.argv[2]
opt = dict(a.split("=", 1) for a in sys.argv[3:])

base = next(
    (os.path.join(r, "") for r, _d, files in os.walk(src) if "cyberpunk-conky.conf" in files),
    None,
)
if not base:
    sys.exit("cyberpunk-conky.conf not found in the archive")

os.makedirs(dest, exist_ok=True)
for f in ("cyberpunk-conky.lua", "LICENSE", "README.md", "CHANGELOG.md"):
    if os.path.exists(base + f):
        shutil.copy(base + f, os.path.join(dest, f))


def lua_str(v):
    level = "="
    while f"]{level}]" in v:
        level += "="
    return f"[{level}[{v}]{level}]"


conf = open(base + "cyberpunk-conky.conf", encoding="utf-8").read()
subs = {
    "minimum_width": opt["width"],
    "minimum_height": opt["height"],
}
for k, v in subs.items():
    conf, n = re.subn(rf"(\b{k}\s*=\s*)\d+", rf"\g<1>{v}", conf)
    if n != 1:
        sys.exit(f"couldn't set {k}")
templates = {
    "template1": opt["font"],
    "template2": opt["iface"],
    "template3": opt["tz"],
    "template4": opt["cpu"],
    "template5": opt["sys"],
    "template6": opt["gpu"],
    "template7": opt["power"],
}
for k, v in templates.items():
    conf, n = re.subn(rf'(\b{k}\s*=\s*)"[^"\n]*"', lambda m: m.group(1) + lua_str(v), conf)
    if n != 1:
        sys.exit(f"couldn't set {k}")
conf, n = re.subn(
    r"(conky\.config\s*=\s*\{\n)",
    "\\1    -- Night City: GNOME has no wlr-layer-shell, so draw through XWayland\n"
    "    out_to_x = true,\n    out_to_wayland = false,\n",
    conf,
    count=1,
)
if n != 1:
    sys.exit("conky.config block not found")
open(os.path.join(dest, "cyberpunk-conky.conf"), "w", encoding="utf-8").write(conf)

lua_path = os.path.join(dest, "cyberpunk-conky.lua")
lua = open(lua_path, encoding="utf-8").read()
old_fetch = "neofetch --off --color_blocks off --disable shell term wm theme icons memory | sed '1,3d' | grep ':'"
if old_fetch in lua:
    lua = lua.replace(
        old_fetch,
        "fastfetch --config none --logo none --pipe -s os:host:kernel:uptime:packages:cpu:gpu:disk:battery",
    )
else:
    print("note: neofetch call not found; SYSTEM INFO box left as shipped", file=sys.stderr)
lua = lua.replace("00FFFF", "00F0FF").replace("EA4A5A", "FF003C")
open(lua_path, "w", encoding="utf-8").write(lua)

gpu = os.path.join(dest, "gpu-load.sh")
open(gpu, "w").write(r"""#!/bin/sh
# GPU load for the HUD's BRAINDANCE box.
# AMD: gpu_busy_percent. Intel has no utilisation counter readable without root, so this
# prints the current GPU clock as a percentage of its maximum, a decent "how busy" proxy.
for c in /sys/class/drm/card*; do
	if [ -r "$c/device/gpu_busy_percent" ]; then cat "$c/device/gpu_busy_percent"; exit 0; fi
	if [ -r "$c/gt_act_freq_mhz" ] && [ -r "$c/gt_RP0_freq_mhz" ]; then
		awk 'NR == 1 { a = $1 } NR == 2 { if ($1 > 0) printf "%d\n", a * 100 / $1; else print 0 }' \
			"$c/gt_act_freq_mhz" "$c/gt_RP0_freq_mhz"
		exit 0
	fi
done
command -v nvidia-smi >/dev/null 2>&1 && exec nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits
echo 0
""")
os.chmod(gpu, 0o755)
print(os.path.join(dest, "cyberpunk-conky.conf"))
