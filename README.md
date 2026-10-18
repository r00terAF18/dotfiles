# dotfiles

My EndeavourOS setup with HyprYou/Hyprland and Xfce as a fallback (fish, bash, starship, kitty, yt-dlp/tiddl helpers). The existing GNOME restore workflow remains available.

## Layout

| Path | What |
| --- | --- |
| `home/` | Mirrors `$HOME`, including the current Plasma and Xfce settings. Every file here is symlinked to the same path under `~`. |
| `scripts/` | Clearly named setup, link, backup, restore, package, GNOME, AI-tools, and Night City workflows. See [`scripts/README.md`](scripts/README.md). |
| `gnome/` | GNOME restore data: `settings.ini` (curated dconf export), `extensions.txt`, and `packages.txt`. |
| `packages/` | Package manifests: `pacman.txt` (native) and `aur.txt` (AUR). |
| `SYSTEM.md` | One-time sudo steps (services etc.). |
| `scripts/` | Standalone helpers: `classes.py` (table of my classes with times and links), `split.py` (split a recording into N chunks), `hfetch.sh` (neofetch with a random cover image). |
| `themes/night-city/` | Optional Cyberpunk 2077 theme data (GTK, Shell, kitty, starship, fish, btop, …). Its workflows are under `scripts/night-city/`, outside the default setup. |
| `legacy/` | Old Hyprland/Quickshell, Xfce, polybar (blocky), Zsh/p10k, Alacritty configs. Not used anymore, kept for reference. |

## Usage

```sh
git clone git@github.com:r00terAF18/dotfiles.git ~/dotfiles
cd ~/dotfiles
scripts/setup-system.sh   # interactive fresh-system workflow
scripts/link-dotfiles.sh --dry-run # preview home symlinks
scripts/gnome/restore-settings.sh --dry-run
scripts/packages/install.sh --dry-run
```

### HyprYou / Hyprland

`hypryou` is listed in `packages/aur.txt` and installed through the package workflow with `yay`. After installation, choose the **HyprYou** session in the login manager; keep **Xfce** available as the fallback session. HyprYou provides its own session configuration, so this repo does not symlink a HyprYou config into `~/.config`.

### Adding a config

Copy it into `home/` at the same relative path, then run `scripts/link-dotfiles.sh`
(it backs up the original and links the repo copy in place).

### Updating snapshots

```sh
scripts/gnome/export-settings.sh       # refresh gnome/settings.ini from dconf
scripts/packages/install.sh --dump     # refresh package lists
scripts/backup-desktop-configs.sh      # private snapshot of installed desktop settings
```

Notes:
- Links are per file, so apps can still drop extra files next to them (e.g. `~/.config/fish/fish_variables`) without touching the repo.
- Some apps save by replacing the file (e.g. Goverlay for `MangoHud.conf`). If a link turns back into a regular file, copy it into `home/` and re-run `scripts/link-dotfiles.sh`.
- No Flatpak anywhere, on purpose.

## Coding-agent tools (`ai-tools/`)

`scripts/ai-tools/setup.sh` installs [Serena](https://github.com/oraios/serena) as a uv tool and registers
Serena, [Context7](https://github.com/upstash/context7) and [Repomix](https://github.com/yamadashy/repomix)
as MCP servers. Cursor's config lives in `home/.cursor/mcp.json` (symlinked by `scripts/link-dotfiles.sh`); GapCode
rewrites its own `config.toml`, so it's configured through `gapcode mcp add` instead of a symlink.
The matching CLI tools (ast-grep, ctags, tree-sitter, jq/yq, language servers, ...) are in `packages/pacman.txt`.

## Night City theme (`themes/night-city/`)

An optional Cyberpunk 2077 look that sits on top of everything above and is fully reversible. It doesn't change
`home/` and isn't run by `scripts/setup-system.sh`.

```sh
scripts/night-city/install.sh --dry-run && scripts/night-city/install.sh # backs up first
scripts/night-city/uninstall.sh                                         # restores the backup
```

See [`themes/night-city/README.md`](themes/night-city/README.md).
