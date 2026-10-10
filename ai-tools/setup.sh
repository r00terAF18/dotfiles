#!/usr/bin/env bash
# Coding-agent helpers: Serena (semantic code tools), Context7 (library docs), Repomix (repo packing)
# for Cursor (~/.cursor/mcp.json, linked by install.sh) and GapCode (~/.gapcode/config.toml).
# Idempotent. usage: ai-tools/setup.sh
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

command -v uv >/dev/null || { echo "uv missing: sudo pacman -S uv" >&2; exit 1; }
command -v npx >/dev/null || { echo "npx missing: sudo pacman -S npm" >&2; exit 1; }

# Serena as a uv tool (fast startup, no download on every launch)
if command -v serena >/dev/null; then uv tool upgrade serena-agent 2>/dev/null || true
else uv tool install git+https://github.com/oraios/serena; fi
SERENA="$HOME/.local/bin/serena"

# GapCode: GapCode rewrites config.toml itself, so it's configured via its CLI instead of a symlink
GAPCODE="$HOME/.gapcode/bin/gapcode"
if [[ -x "$GAPCODE" ]]; then
	add() { local name="$1"; shift; "$GAPCODE" mcp remove "$name" >/dev/null 2>&1 || true; "$GAPCODE" mcp add "$name" -- "$@"; }
	add serena "$SERENA" start-mcp-server --context codex --project-from-cwd --open-web-dashboard false
	add context7 npx -y @upstash/context7-mcp
	add repomix npx -y repomix --mcp
else
	echo "GapCode not installed (~/.gapcode/bin/gapcode), skipping its MCP setup."
fi

echo "Done. Cursor uses ~/.cursor/mcp.json (run ./install.sh if it isn't linked yet). Restart Cursor/GapCode."
