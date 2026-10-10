# dotfiles

My EndeavourOS + GNOME setup (fish, bash, starship, kitty, yt-dlp/tiddl helpers).

## Layout

| Path | What |
| --- | --- |
| `home/` | Mirrors `$HOME`. Every file here is symlinked to the same path under `~`. |
| `install.sh` | Creates those symlinks. Existing files go to `~/.dotfiles-backup/<timestamp>/`. Idempotent, supports `--dry-run`. |
| `gnome/` | GNOME restore: `settings.ini` (curated dconf), `extensions.txt`, `packages.txt`, `setup.sh`, `dump.sh`. |
| `packages/` | `pacman.txt` (native) and `aur.txt` (AUR) plus `install.sh` (`--needed`, `--dry-run`, `--dump`). |
| `bootstrap.sh` | Runs packages → install.sh → gnome/setup.sh, asking before each step. |
| `SYSTEM.md` | One-time sudo steps (services etc.). |
| `scripts/` | Standalone helpers: `classes.py` (table of my classes with times and links), `split.py` (split a recording into N chunks), `hfetch.sh` (neofetch with a random cover image). |
| `themes/night-city/` | Optional Cyberpunk 2077 theme (GTK, Shell, kitty, starship, fish, btop, …) with backup/install/uninstall scripts. Not part of `bootstrap.sh`. |
| `legacy/` | Old Hyprland/Quickshell, Xfce, polybar (blocky), Zsh/p10k, Alacritty configs. Not used anymore, kept for reference. |

## Usage

```sh
git clone git@github.com:r00terAF18/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh            # or run the pieces individually:
./install.sh --dry-run    # preview symlinks
./install.sh
gnome/setup.sh --dry-run
packages/install.sh --dry-run
```

### Adding a config

Copy it into `home/` at the same relative path, then run `./install.sh`
(it backs up the original and links the repo copy in place).

### Updating snapshots

```sh
gnome/dump.sh              # refresh gnome/settings.ini from dconf
packages/install.sh --dump # refresh package lists
```

Notes:
- Links are per file, so apps can still drop extra files next to them (e.g. `~/.config/fish/fish_variables`) without touching the repo.
- Some apps save by replacing the file (e.g. Goverlay for `MangoHud.conf`). If a link turns back into a regular file, copy it into `home/` and re-run `./install.sh`.
- No Flatpak anywhere, on purpose.

## Coding-agent tools (`ai-tools/`)

`ai-tools/setup.sh` installs [Serena](https://github.com/oraios/serena) as a uv tool and registers
Serena, [Context7](https://github.com/upstash/context7) and [Repomix](https://github.com/yamadashy/repomix)
as MCP servers. Cursor's config lives in `home/.cursor/mcp.json` (symlinked by `install.sh`); GapCode
rewrites its own `config.toml`, so it's configured through `gapcode mcp add` instead of a symlink.
The matching CLI tools (ast-grep, ctags, tree-sitter, jq/yq, language servers, ...) are in `packages/pacman.txt`.

## Night City theme (`themes/night-city/`)

An optional Cyberpunk 2077 look that sits on top of everything above and is fully reversible. It doesn't change
`home/` and isn't run by `bootstrap.sh`.

```sh
themes/night-city/install.sh --dry-run && themes/night-city/install.sh   # backs up first
themes/night-city/uninstall.sh                                          # restores the backup
```

See [`themes/night-city/README.md`](themes/night-city/README.md).
