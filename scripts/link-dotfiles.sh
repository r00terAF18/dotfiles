#!/usr/bin/env bash
# Symlink every file under home/ into $HOME (file-level links, not whole dirs).
# Existing files are moved to ~/.dotfiles-backup/<timestamp>/<path> first.
# Safe to re-run: correct links are left alone.
#
# usage: scripts/link-dotfiles.sh [--dry-run|-n] [--only RELATIVE_PATH]
set -euo pipefail

DRY_RUN=0
ONLY_REL=""
while (($#)); do
	case "$1" in
		-n | --dry-run) DRY_RUN=1 ;;
		--only)
			(($# >= 2)) || { echo "--only requires a path under home/" >&2; exit 1; }
			ONLY_REL="$2"
			shift
			;;
		-h | --help) sed -n '2,6p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SRC_DIR="$REPO_DIR/home"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

if [[ -n "$ONLY_REL" && ! -e "$SRC_DIR/$ONLY_REL" && ! -L "$SRC_DIR/$ONLY_REL" ]]; then
	echo "not found under home/: $ONLY_REL" >&2
	exit 1
fi

run() {
	if ((DRY_RUN)); then
		printf '  [dry-run] %s\n' "$*"
	else
		"$@"
	fi
}

linked=0 skipped=0 backed_up=0

while IFS= read -r -d '' src; do
	rel="${src#"$SRC_DIR"/}"
	[[ -z "$ONLY_REL" || "$rel" == "$ONLY_REL" ]] || continue
	dest="$HOME/$rel"

	if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
		echo "ok       ~/$rel"
		skipped=$((skipped + 1))
		continue
	fi

	if [[ -e "$dest" || -L "$dest" ]]; then
		echo "backup   ~/$rel -> $BACKUP_DIR/$rel"
		run mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
		run mv "$dest" "$BACKUP_DIR/$rel"
		backed_up=$((backed_up + 1))
	fi

	echo "link     ~/$rel -> $src"
	run mkdir -p "$(dirname "$dest")"
	run ln -s "$src" "$dest"
	linked=$((linked + 1))
done < <(find "$SRC_DIR" \( -type f -o -type l \) -print0 | sort -z)

echo
echo "linked: $linked, already ok: $skipped, backed up: $backed_up"
((DRY_RUN)) && echo "(dry run, nothing changed)"
((backed_up)) && ((!DRY_RUN)) && echo "backups in: $BACKUP_DIR"
exit 0
