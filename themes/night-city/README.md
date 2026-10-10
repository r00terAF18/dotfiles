# Night City — a Cyberpunk 2077 theme

A Cyberpunk 2077 look for EndeavourOS + GNOME 51. It layers on top of the normal setup and comes off
cleanly. Nothing in `home/` is touched. The WhiteSur theme stays installed, and uninstalling
switches back to it.

Black backgrounds, Arasaka-yellow accent, netrunner-cyan focus and selection, and red/magenta for alerts.
Rajdhani is used for **titles only**: window titles, headerbar titles and the top-bar clock.

## Palette (`palette.sh`, the single source of truth)

| Name | Hex | Used for |
| --- | --- | --- |
| `BG0` | `#0A0A0F` | window / terminal background |
| `BG1` | `#12131A` | headerbars, sidebars, panel |
| `BG2` | `#1B1D26` | cards, popovers, inactive tabs |
| `BORDER` | `#2A2D3A` | borders, separators |
| `FG` | `#E4F7F7` | text |
| `FG_DIM` | `#7A8C99` | secondary text, comments |
| `YELLOW` / `YELLOW_DIM` | `#FCEE0A` / `#C4B800` | accent, buttons, active tab, cursor |
| `CYAN` / `CYAN_DIM` | `#00F0FF` / `#02D7F2` | focus rings, selection, links |
| `RED` | `#FF003C` | errors, destructive actions |
| `MAGENTA` | `#FF2BD6` | highlights, git status |
| `GREEN` | `#00FF9F` | success |
| `ORANGE` | `#FF8A00` | warnings |
| `BLUE` / `PURPLE` | `#3D7BFF` / `#B967FF` | ANSI blue / extra |
| bright ANSI | `#555B70 #FF4D6D #5CFFC0 #FFF75C #7AA5FF #FF7AE6 #66F6FF #FFFFFF` | terminal brights |

To change a colour, edit `palette.sh` and run `./generate.sh`. It re-renders `dist/` in place, and
everything is linked to `dist/`, so apps pick up the change on their next reload. Commit `dist/`
along with the palette. `./generate.sh --check` tells you whether `dist/` is stale.

## Layout

```
themes/night-city/
├── palette.sh            colours (NC_* variables)
├── generate.sh           templates/**/*.in -> dist/ ({{name}}, {{name_hex}}, {{name_rgb}})
├── templates/            sources of everything below
├── dist/                 rendered files (what gets linked)
│   ├── gtk-4.0/gtk.css           libadwaita: :root variables + @define-color, title font, neon headerbar line
│   ├── gtk-3.0/gtk.css           adw-gtk3 colour overrides
│   ├── themes/NightCity/gnome-shell/gnome-shell.css   minimal shell theme on top of the default
│   ├── kitty/night-city.conf     colours, tab bar, cursor trail
│   ├── starship/starship.toml    powerline prompt, palette "night_city"
│   ├── fish/night-city.fish      fish syntax colours + STARSHIP_CONFIG
│   ├── btop/night-city.theme
│   ├── fastfetch/config.jsonc
│   ├── fastfetch/kiroshi.txt
│   ├── cava/config               cyan -> magenta -> red -> yellow gradient
│   ├── mangohud/MangoHud.conf    your MangoHud keys/blacklist, recoloured
│   ├── burn-my-windows/night-city.conf   TV-glitch open/close, yellow, 500 ms
│   └── environment.d/60-night-city.conf  STARSHIP_CONFIG, MANGOHUD_CONFIGFILE
├── settings/dconf.txt    every dconf key the theme sets (key value)
├── lib/common.sh         paths, file list, packages, helpers shared by the scripts
├── lib/ncjson.py         JSON/GVariant helpers (settings.json, manifest, extension lists)
├── backup.sh
├── install.sh
└── uninstall.sh
```

## Where each piece goes

| Piece | How it's applied | Doesn't touch |
| --- | --- | --- |
| GTK4 / libadwaita | link `~/.config/gtk-4.0/gtk.css`; dconf `color-scheme 'prefer-dark'`, `accent-color 'yellow'` | — (no gtk.css existed) |
| GTK3 | `adw-gtk-theme` package, `gtk-theme 'adw-gtk3-dark'`, link `~/.config/gtk-3.0/gtk.css` | WhiteSur stays installed |
| GNOME Shell | `~/.local/share/themes/NightCity` link, `user-theme name 'NightCity'` | |
| Icons / cursor | `Papirus-Dark` + `papirus-folders -C yellow`; `Cyberpunk-Neon` cursor by default, or `Bibata-Modern-Amber` with `--cursor bibata` | |
| Title font | Rajdhani → `~/.local/share/fonts/night-city`; `titlebar-font 'Rajdhani Bold 12'` | interface/monospace fonts |
| Blur my Shell / Just Perfection | dconf keys in `settings/dconf.txt` (dark panel blur, dark overview, no workspace popup) | |
| Burn My Windows | per-user from extensions.gnome.org (the AUR build doesn't support GNOME 51 yet); profile *copied* to `~/.config/burn-my-windows/profiles/` because the extension rewrites it | |
| kitty | link `current-theme.conf` (your `kitty.conf` already ends with `globinclude current-theme.conf`) **and** `dark-theme.auto.conf`, because kitty's auto dark theme overrides colours in dark mode. The old "Cherry" `dark-theme.auto.conf` goes into the backup | `kitty.conf` |
| starship | `STARSHIP_CONFIG` (environment.d for the session, plus `conf.d/night-city.fish` so new fish shells get it straight away) | `home/.config/starship.toml` |
| fish | `~/.config/fish/conf.d/night-city.fish` (interactive only, `set -g fish_color_*`) | `config.fish`, universal vars |
| btop | theme file + `color_theme = "night-city"` in `btop.conf` (old value saved) | |
| Fastfetch | link `config.jsonc` and the Kiroshi-inspired ASCII optic `kiroshi.txt` | |
| cava | link `config` | |
| MangoHud | `MANGOHUD_CONFIGFILE` via environment.d (see below) | the `MangoHud.conf` symlink |
| VS Code / Cursor | `Endormi.2077-theme` extension, `workbench.colorTheme` + `workbench.preferredDarkColorTheme` = `"2077"` | every other key |
| Firefox | manual: [Cyberpunk 2077 UI on AMO](https://addons.mozilla.org/en-US/firefox/addon/cyberpunk-2077-ui/) → *Add to Firefox*. Remove it under `about:addons` → Themes | |

**Why MangoHud uses an environment variable.** Your `~/.config/MangoHud/MangoHud.conf` is a dotfiles
symlink, and Goverlay sometimes replaces it. Swapping that link would mean juggling two
owners of one path. MangoHud reads `MANGOHUD_CONFIGFILE` before its default path, so the theme
only adds `~/.config/environment.d/60-night-city.conf`, which points at its own recoloured copy.
Uninstalling deletes that one link. Your file isn't touched. To change HUD keys while the theme is on,
edit `templates/mangohud/MangoHud.conf.in` and re-run `./generate.sh`.

## Packages (verified 2026-10-10, pacman first, then yay, all `--needed`, no Flatpak)

| Source | Packages |
| --- | --- |
| extra | `adw-gtk-theme` `papirus-icon-theme` `btop` `cava` `fastfetch` |
| AUR | `papirus-folders` `bibata-cursor-theme-bin` `gnome-shell-extension-blur-my-shell` (74, GNOME 46–51) `gnome-shell-extension-just-perfection-desktop` (37, GNOME 45–51) |
| AUR, optional | `ttf-orbitron` (`--with-orbitron`; not used by any config, it's just for you) |
| extensions.gnome.org | Burn My Windows (`gnome-extensions install`, per user) |
| VS Code Marketplace / Open VSX | `Endormi.2077-theme` |
| google/fonts (GitHub, jsDelivr mirror) | Rajdhani (OFL), titles only |

Packages that are already installed, or provided by another package (`pacman -T`), are skipped. The
install records exactly what it installed, and `uninstall.sh --remove-packages` removes only those.

## The scripts

All three are bash with `set -euo pipefail`, take `--dry-run`, and can be run again safely. Confirmation
questions default to *no* unless you pass `--yes`; optional components remain opt-in with `--yes` and are
skipped unless their flags are supplied. `sudo` is used only for package installation, papirus-folders,
and the optional Plymouth boot splash.

### `backup.sh [--dry-run] [--dest DIR]`
1. Creates `~/.night-city-backup/<YYYYmmdd-HHMMSS>/`.
2. Saves `dconf dump /` (full), the dumps of the blur-my-shell / just-perfection / burn-my-windows / user-theme subtrees, and
   the current value (or "unset") of every key in `settings/dconf.txt`. The font keys are saved too, for reference.
3. Saves the enabled/disabled extension lists and which theme extensions are installed.
4. For every file the theme deploys, saves a copy of what's there now (file or symlink, kept as is), or notes that nothing was there.
   Also saves the dirs that don't exist yet (so uninstall can remove the ones the theme creates), `btop.conf`, the MangoHud link
   and both editors' `settings.json`, with the theme keys and whether the 2077 extension is installed.
5. Saves package presence, the papirus-folders colour and whether the font dir existed. Writes `manifest.json`.
6. Read-only apart from the backup dir. `--dry-run` collects into a temp dir, prints the summary and deletes it.

### `install.sh [--dry-run] [--yes] [--skip-packages] [--with-orbitron] [--no-editors] [--reapply] [--cursor neon|bibata|keep] [--icons papirus] [--borders [glow|highlight|none]] [--with-conky] [--with-boot] [--boot-theme cybernetic|glitch]`
0. Checks the tools it needs, reads the GNOME Shell version and renders `dist/` (in dry-run it only checks it).
1. Runs `backup.sh` into a new backup dir and **stops if the backup fails**. The first install marks it as the
   pre-theme backup (`~/.night-city-backup/active`), so later re-installs never overwrite that reference.
   Every change from here on is logged to `<backup>/state.tsv` (and `state.json`).
2. Packages: lists what's missing, then asks before `sudo pacman -S --needed` and before `yay -S --needed`.
3. Burn My Windows from extensions.gnome.org, for your Shell version (per user, no sudo; a warning if it can't be reached).
4. Rajdhani: downloads from GitHub, falling back to jsDelivr. If both are blocked it warns and carries
   on, and titles stay in the default font. Runs `fc-cache`.
5. Links each file from the table. Anything already there that isn't ours is moved into `<backup>/displaced/`.
   Links that already point at the theme are left as they are.
6. btop: sets `color_theme` (creates `btop.conf` with just that line if btop never ran).
7. dconf: writes each key from `settings/dconf.txt` that differs and logs the old value. Enables user-theme, Blur my Shell,
   Burn My Windows and Just Perfection, and logs only the ones it added.
8. `papirus-folders -C yellow --theme Papirus-Dark` (asks; it uses sudo).
9. For each editor with a CLI: installs `Endormi.2077-theme` if missing and sets the two theme keys. A `settings.json`
   with comments/trailing commas is left alone, with a warning.
10. Prints the next steps (log out/in, etc.).

Optional parts are the Cyberpunk-Neon cursor (default), window border, Conky HUD, and Plymouth boot
splash. `--yes` answers confirmation prompts but does not select optional parts; add their flags to opt in.
The boot splash automation requires systemd-boot, dracut, and `kernel-install-for-dracut`.

### `uninstall.sh [--dry-run] [--yes] [--backup DIR] [--remove-packages]`
1. Uses the pre-theme backup (`active` marker), or the latest backup taken while the theme was off, or `--backup DIR`.
   Reads `state.tsv` from that backup and from every later one (re-installs).
2. Files: removes each link/copy only if it's still the theme's. Then puts back the saved original (e.g. kitty's
   Cherry `dark-theme.auto.conf`) or leaves nothing if there was none. Anything you replaced yourself is reported and left alone.
3. btop: restores the old `color_theme`. If install created `btop.conf` and it holds only that line, it's removed.
4. dconf: each key goes back to its old value (or is reset) **only if it still holds the theme's value**.
   Extensions the theme enabled get disabled again. Nothing else in your list changes.
5. Editors: the two keys are restored only if they're still `"2077"`. If nothing else changed, the original file is put back byte for byte.
6. Papirus: the previous folder colour comes back (or `papirus-folders -D`).
7. Optional system files from the Plymouth splash are restored only when their recorded post-install
   fingerprints still match. Older state logs without fingerprints are left for manual review.
8. `--remove-packages`: also removes what *this theme* installed (`pacman -Rns`, the Burn My Windows extension,
   the 2077 editor extension, the Rajdhani dir). Without it, packages stay; they're harmless.
9. Deletes empty dirs the theme created and the `active` marker. **Backups are kept.** Delete
   `~/.night-city-backup` yourself when you're happy.

## Commands

```sh
cd ~/dotfiles/themes/night-city
./backup.sh                     # optional; install.sh makes its own backup anyway
./install.sh --dry-run          # see exactly what would happen
./install.sh                    # asks before sudo/yay/papirus-folders
# log out and back in (Wayland can't reload the Shell theme, extensions or environment.d any other way)

./uninstall.sh --dry-run
./uninstall.sh                  # or: ./uninstall.sh --remove-packages
# log out and back in again
```

`bootstrap.sh` does **not** run this. To include it in a fresh setup, run `themes/night-city/install.sh` after
`bootstrap.sh`, or add that line to the end of `bootstrap.sh` yourself.

## Caveats

- **Log out and back in** after install/uninstall. Until then the Shell theme, extensions, `STARSHIP_CONFIG` in bash
  and `MANGOHUD_CONFIGFILE` don't apply. kitty: `ctrl+shift+f5`. GTK apps: restart them.
- libadwaita only exposes colours and a little CSS. The `gtk-4.0/gtk.css` sets dark colours on `:root`,
  so if you flip GNOME to *light* style while the theme is on, libadwaita apps stay dark. That's expected.
  Apps that ship their own styling (Electron, Firefox, Qt) ignore it.
- The Shell theme is deliberately minimal (panel, menus, quick settings, OSD, switcher, dialogs). The rest is
  GNOME's default stylesheet underneath, so Shell updates shouldn't break it.
- `kitten themes` writes `current-theme.conf` (and can write `dark-theme.auto.conf`), which replaces the theme's links. Uninstall
  notices the change and leaves your choice alone.
- Burn My Windows comes from extensions.gnome.org, not the AUR, so it updates through the Extensions app.
- Wallpapers aren't included. Use the filtered Wallhaven search from the research notes
  (`cyberpunk 2077`, *General*, *SFW*, 16:9, ≥2560×1440) with your wallpaper manager.
- No GRUB or GDM theming. The optional Plymouth splash is automated only for systemd-boot + dracut +
  `kernel-install-for-dracut`; other boot setups are left untouched.
