#!/usr/bin/env python3
"""JSON / GVariant helpers for the Night City scripts (stdlib only).

  editor-read FILE KEY...            current values of settings.json keys, as JSON
  editor-set FILE JSON               set keys from a JSON object (null deletes the key)
  editor-restore FILE MANIFEST NAME  put back the keys recorded for editor NAME in a backup
  gv-add LIST ITEM...                GVariant string list with ITEMs appended (if missing)
  gv-remove LIST ITEM...             GVariant string list without ITEMs
  gv-has LIST ITEM                   exit 0 if ITEM is in the list
  manifest-build DIR                 write DIR/manifest.json from the files backup.sh staged
  manifest-get MANIFEST PATH         print a value (dotted path); strings raw, others as JSON
  manifest-files MANIFEST            files section as TSV: target kind link saved parent_existed
  state-json DIR                     write DIR/state.json from DIR/state.tsv
"""
import ast
import json
import os
import sys
from datetime import datetime


def die(msg, code=1):
    print(f"ncjson: {msg}", file=sys.stderr)
    sys.exit(code)


# ---- settings.json ----
def load_settings(path):
    """Return (exists, data). Exit 3 if the file is not strict JSON (comments etc.)."""
    if not os.path.exists(path):
        return False, {}
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.strip():
        return True, {}
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        die(f"{path} is not plain JSON ({e}); comments/trailing commas would be lost, so it is left alone", 3)
    if not isinstance(data, dict):
        die(f"{path}: top level is not an object", 3)
    return True, data


def save_settings(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".night-city.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)


def editor_read(path, *keys):
    exists, data = load_settings(path)
    print(json.dumps({
        "exists": exists,
        "present": {k: k in data for k in keys},
        "values": {k: data.get(k) for k in keys},
    }))


def editor_set(path, updates_json):
    _, data = load_settings(path)
    for k, v in json.loads(updates_json).items():
        if v is None:
            data.pop(k, None)
        else:
            data[k] = v
    save_settings(path, data)


def editor_restore(path, manifest, name):
    with open(manifest, encoding="utf-8") as f:
        ed = json.load(f).get("editors", {}).get(name)
    if not ed or ed.get("settings") is None:
        die(f"no settings recorded for {name}", 2)
    rec = ed["settings"]
    updates = {k: (rec["values"][k] if rec["present"][k] else None) for k in rec["present"]}
    editor_set(path, json.dumps(updates))


# ---- GVariant string lists ("['a', 'b']" or "@as []") ----
def gv_parse(s):
    s = s.strip()
    if s.startswith("@as"):
        s = s[3:].strip()
    if not s:
        return []
    return list(ast.literal_eval(s))


def gv_format(items):
    if not items:
        return "@as []"
    return "[" + ", ".join("'" + i.replace("'", "\\'") + "'" for i in items) + "]"


def gv_add(lst, *items):
    cur = gv_parse(lst)
    cur += [i for i in items if i not in cur]
    print(gv_format(cur))


def gv_remove(lst, *items):
    print(gv_format([i for i in gv_parse(lst) if i not in items]))


def gv_has(lst, item):
    sys.exit(0 if item in gv_parse(lst) else 1)


# ---- backup manifest ----
def read_tsv(path, ncols):
    rows = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if line:
                    parts = line.split("\t")
                    rows.append(parts + [""] * (ncols - len(parts)))
    return rows


def manifest_build(d):
    misc = {k: v for k, v in read_tsv(os.path.join(d, "misc.tsv"), 2)}
    m = {
        "version": 1,
        "created": misc.pop("created", datetime.now().isoformat(timespec="seconds")),
        "theme_dir": misc.pop("theme_dir", ""),
        "theme_active_when_taken": misc.pop("theme_active", "0") == "1",
        "gnome_shell": misc.pop("shell_version", ""),
        "files": [
            {"target": t, "kind": k, "link": l or None, "saved": s or None, "parent_existed": p == "1"}
            for t, k, l, s, p in read_tsv(os.path.join(d, "files.tsv"), 5)
        ],
        "dconf": [
            {"key": k, "set": st == "set", "value": v if st == "set" else None, "managed": mg == "1"}
            for k, st, v, mg in read_tsv(os.path.join(d, "dconf.tsv"), 4)
        ],
        "extensions": {
            "enabled": misc.pop("enabled_extensions", "@as []"),
            "disabled": misc.pop("disabled_extensions", "@as []"),
            "items": [
                {"uuid": u, "installed": i == "1", "location": loc or None}
                for u, i, loc in read_tsv(os.path.join(d, "extensions.tsv"), 3)
            ],
        },
        "packages": [
            {"name": n, "present": p == "1", "version": v or None}
            for n, p, v in read_tsv(os.path.join(d, "packages.tsv"), 3)
        ],
        "editors": {},
        "papirus_folders": {
            "installed": misc.pop("papirus_installed", "0") == "1",
            "color": misc.pop("papirus_color", "") or None,
        },
        "btop": {
            "conf_existed": misc.pop("btop_conf_existed", "0") == "1",
            "color_theme": misc.pop("btop_color_theme", "") or None,
        },
        "mangohud": {
            "path": misc.pop("mangohud_path", ""),
            "kind": misc.pop("mangohud_kind", ""),
            "link": misc.pop("mangohud_link", "") or None,
        },
        "fonts_dir_existed": misc.pop("fonts_dir_existed", "0") == "1",
    }
    eddir = os.path.join(d, "editors")
    if os.path.isdir(eddir):
        for fn in sorted(os.listdir(eddir)):
            if fn.endswith(".json"):
                with open(os.path.join(eddir, fn), encoding="utf-8") as f:
                    m["editors"][fn[:-5]] = json.load(f)
    m["other"] = misc
    with open(os.path.join(d, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, indent=2, ensure_ascii=False)
        f.write("\n")


def manifest_get(path, dotted):
    with open(path, encoding="utf-8") as f:
        v = json.load(f)
    for part in dotted.split("."):
        if isinstance(v, dict):
            v = v.get(part)
        elif isinstance(v, list) and part.isdigit():
            v = v[int(part)]
        else:
            v = None
        if v is None:
            break
    if v is None:
        return
    print(v if isinstance(v, str) else json.dumps(v))


def manifest_files(path):
    with open(path, encoding="utf-8") as f:
        m = json.load(f)
    for e in m["files"]:
        print("\t".join([e["target"], e["kind"], e["link"] or "", e["saved"] or "", "1" if e["parent_existed"] else "0"]))


def state_json(d):
    out = {}
    for row in read_tsv(os.path.join(d, "state.tsv"), 3):
        kind, rest = row[0], [x for x in row[1:] if x]
        out.setdefault(kind, []).append(rest[0] if len(rest) == 1 else rest)
    with open(os.path.join(d, "state.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
        f.write("\n")


CMDS = {
    "editor-read": editor_read, "editor-set": editor_set, "editor-restore": editor_restore,
    "gv-add": gv_add, "gv-remove": gv_remove, "gv-has": gv_has,
    "manifest-build": manifest_build, "manifest-get": manifest_get,
    "manifest-files": manifest_files, "state-json": state_json,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in CMDS:
        print(__doc__)
        sys.exit(1)
    CMDS[sys.argv[1]](*sys.argv[2:])
