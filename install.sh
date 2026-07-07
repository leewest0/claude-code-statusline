#!/bin/bash
# Installer for claude-code-statusline.
#
#   curl -fsSL https://raw.githubusercontent.com/leewest0/claude-code-statusline/main/install.sh | bash
#
# or, from a clone of this repo:
#
#   ./install.sh
#
# Copies statusline.sh into ~/.claude/statusline.sh and prints exactly what to
# add to ~/.claude/settings.json. It never edits settings.json for you — that
# file may hold config unrelated to the status line, so merging is manual.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/leewest0/claude-code-statusline/main"
CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not installed." >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Linux:  apt install jq   (or your distro's package manager)" >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"

# When run from a clone (./install.sh), use the local statusline.sh sitting
# next to this script. When piped through `curl | bash`, BASH_SOURCE isn't a
# real file, so fall back to downloading it from GitHub.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/statusline.sh" ]; then
  cp "$SCRIPT_DIR/statusline.sh" "$TARGET"
else
  curl -fsSL "$REPO_RAW/statusline.sh" -o "$TARGET"
fi
chmod +x "$TARGET"
echo "Installed statusline.sh -> $TARGET"

STATUSLINE_BLOCK='  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "timeout": 10
  }'

if [ ! -f "$SETTINGS" ]; then
  cat <<EOF

No $SETTINGS found. Create it with:

{
$STATUSLINE_BLOCK
}
EOF
elif jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  cat <<EOF

$SETTINGS already has a "statusLine" entry — left untouched.
Point it at $TARGET if you want to switch to this script.
EOF
else
  cat <<EOF

$SETTINGS exists but has no "statusLine" key. Add this entry (merge, don't overwrite):

{
$STATUSLINE_BLOCK
}
EOF
fi

echo
echo "Restart Claude Code — the status line appears after your first message."
