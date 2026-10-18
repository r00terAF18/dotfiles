# Scripts and workflows

Run these from the repository root. The workflow scripts and their helper code live here; configuration data stays in `home/`, `gnome/`, `packages/`, and `themes/night-city/`.

## Fresh setup and maintenance

| Script | Workflow |
| --- | --- |
| `scripts/setup-system.sh [--yes]` | Run the interactive fresh-system sequence: install packages, link home configs, restore GNOME, then set up AI tools. `--yes` accepts each step. |
| `scripts/link-dotfiles.sh [--dry-run] [--only PATH]` | Link files under `home/` into `$HOME`. `--only PATH` links one path; existing files are moved to `~/.dotfiles-backup/` first. |
| `scripts/backup-desktop-configs.sh` | Save private snapshots of installed desktop settings and package inventory under ignored `backups/`. |
| `scripts/packages/install.sh [--dry-run]` | Install packages from `packages/pacman.txt` and `packages/aur.txt`. `--dump` refreshes those manifests from the current system. |
| `scripts/ai-tools/setup.sh` | Configure Serena, Context7, and Repomix for Cursor and GapCode. |
| `scripts/helpers/yt-dlp.sh` | Bash download functions sourced by `~/.bashrc` through the linked `~/.config/bash/yt-dlp.sh` path. |

## Desktop workflows

| Script | Workflow |
| --- | --- |
| `scripts/gnome/export-settings.sh` | Export the curated current GNOME dconf settings to `gnome/settings.ini`. `--stdout` prints instead of writing. |
| `scripts/gnome/restore-settings.sh [--dry-run]` | Restore GNOME packages, extensions, and settings. `--skip-*` flags select individual parts. |
| `scripts/night-city/generate.sh [--check]` | Render Night City templates into `themes/night-city/dist/`. |
| `scripts/night-city/backup.sh [--dry-run]` | Snapshot Night City managed state; the installer runs this automatically before changes. |
| `scripts/night-city/install.sh [options]` | Install the optional Night City theme. Start with `--dry-run` to preview. |
| `scripts/night-city/uninstall.sh [options]` | Restore the pre-theme state recorded by its backup. Start with `--dry-run` to preview. |

Plasma and Xfce user settings are regular files under `home/.config/`; `scripts/link-dotfiles.sh` links them with the rest of the home mirror. GNOME uses dconf, so it is exported and restored through the GNOME scripts instead.

## Archived scripts

Standalone shell and Python utilities from retired configurations are kept under `scripts/archive/legacy/`, grouped by their former paths. Symlinks remain at old paths where archived configs call them. They are reference material, not part of the fresh-system workflow.

Shell startup files such as `.bashrc` and `config.fish` stay in `home/` because they are configuration entrypoints, not operator workflows.
