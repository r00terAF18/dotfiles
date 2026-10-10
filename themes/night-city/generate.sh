#!/usr/bin/env bash
# Render templates/ into dist/ using the colours in palette.sh.
#   {{name}} -> #RRGGBB   {{name_hex}} -> RRGGBB   {{name_rgb}} -> R, G, B
#
# usage: ./generate.sh [--check]   (--check: only report whether dist/ is up to date)
set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CHECK=0
case "${1:-}" in
	--check) CHECK=1 ;;
	-h | --help) sed -n '2,5p' "$0"; exit 0 ;;
	"") ;;
	*) echo "unknown option: $1" >&2; exit 1 ;;
esac

# shellcheck source=palette.sh
source "$HERE/palette.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
sedscript="$work/palette.sed"
: >"$sedscript"

while IFS= read -r var; do
	val="${!var}"
	if [[ ! "$val" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
		echo "palette.sh: $var='$val' is not a #RRGGBB colour" >&2
		exit 1
	fi
	name="${var#NC_}"
	name="${name,,}"
	hex="${val#\#}"
	printf 's|{{%s}}|%s|g\ns|{{%s_hex}}|%s|g\ns|{{%s_rgb}}|%d, %d, %d|g\n' \
		"$name" "$val" "$name" "$hex" "$name" \
		"$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))" >>"$sedscript"
done < <(compgen -v NC_ | sort)

out="$work/dist"
mkdir -p "$out"
while IFS= read -r -d '' tpl; do
	rel="${tpl#"$HERE/templates/"}"
	rel="${rel%.in}"
	# The GNOME Shell theme lives in a theme directory that user-theme can load by name.
	[[ "$rel" == gnome-shell/* ]] && rel="themes/NightCity/$rel"
	mkdir -p "$(dirname "$out/$rel")"
	sed -f "$sedscript" "$tpl" >"$out/$rel"
	if left="$(grep -o '{{[a-z0-9_]*}}' "$out/$rel" | sort -u | tr '\n' ' ')" && [[ -n "$left" ]]; then
		echo "templates/${tpl#"$HERE/templates/"}: unknown palette names: $left" >&2
		exit 1
	fi
done < <(find "$HERE/templates" -type f -print0 | sort -z)

if ((CHECK)); then
	if diff -r "$out" "$HERE/dist" >/dev/null 2>&1; then
		echo "dist/ is up to date with palette.sh"
	else
		echo "dist/ is out of date; run ./generate.sh" >&2
		exit 1
	fi
	exit 0
fi

# Update dist/ in place (only files whose content changed), so existing symlinks stay valid.
changed=0
while IFS= read -r -d '' f; do
	rel="${f#"$out/"}"
	if ! cmp -s "$f" "$HERE/dist/$rel"; then
		mkdir -p "$(dirname "$HERE/dist/$rel")"
		cp "$f" "$HERE/dist/$rel"
		echo "  updated dist/$rel"
		changed=$((changed + 1))
	fi
done < <(find "$out" -type f -print0 | sort -z)
if [[ -d "$HERE/dist" ]]; then
	while IFS= read -r -d '' f; do
		rel="${f#"$HERE/dist/"}"
		[[ -e "$out/$rel" ]] || { rm -f "$f"; echo "  removed stale dist/$rel"; changed=$((changed + 1)); }
	done < <(find "$HERE/dist" -type f -print0)
fi
echo "dist/: $(find "$out" -type f | wc -l) files, $changed changed"
