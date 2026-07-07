# claude-code-statusline

A gradient, information-dense status line for [Claude Code](https://code.claude.com).
Model, context usage, cost, git branch, rate limits — one glanceable line at the
bottom of your terminal, with zero-value fields hidden so it never looks cluttered.

## Features

- **True-color gradient progress bar** for context window usage (green → yellow → red), with automatic fallback to ANSI-256 or plain ASCII on terminals that don't support 24-bit color
- **Smart hiding** — cost, duration, lines-changed, and rate-limit fields disappear entirely when zero, instead of cluttering the line with `$0.00 | 0m0s | +0/-0`
- **Cost coloring** — dims at $0, normal color under $10, red above $10
- **Cached git branch + dirty indicator** — shells out to `git` at most once every 5 seconds per directory, so it doesn't slow down every keystroke
- **Rate limit tracking** — 5-hour and 7-day usage, red above 80%
- **Worktree / agent indicator** for multi-agent or worktree-based workflows
- Optional **Nerd Font glyphs** and **Powerline-style separators**

## Install

Requires [`jq`](https://jqlang.org/):

```bash
brew install jq   # macOS
```

Then:

```bash
mkdir -p ~/.claude
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json` (merge if you already have one):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "timeout": 10
  }
}
```

Restart Claude Code. The status line appears after your first message in a session.

## Try it first

`examples/test-mock.sh` feeds mock Claude Code session JSON through the real
script (including the actual `jq` parsing), so you can preview the rendering
in your own terminal before wiring it into `settings.json`:

```bash
chmod +x examples/test-mock.sh
./examples/test-mock.sh            # all four scenarios
./examples/test-mock.sh danger     # just one: normal | warning | danger | startup
```

## Configuration

Set these in your shell profile (`~/.zshrc` / `~/.bashrc`) before launching
Claude Code:

| Variable | Effect |
|---|---|
| `CLAUDE_STATUSLINE_ASCII=1` | Force plain ASCII — no color, no unicode |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Use Nerd Font glyphs instead of unicode symbols |
| `CLAUDE_STATUSLINE_POWERLINE=1` | Use arrow-style powerline separators (defaults on with Nerd Font) |

`COLORTERM=truecolor` (usually already set by your terminal) enables the
24-bit gradient; otherwise it falls back to a fixed-threshold ANSI-256 palette.

## How it works

Claude Code pipes a JSON blob describing the current session to your script's
stdin on every render (throttled to ~300ms), and whatever the script prints
to stdout becomes the status line. This script:

1. Reads that JSON with a single `jq` call into a tab-separated line
2. Renders a gradient bar, colored by position, for context usage
3. Applies smart-hide rules to cost/duration/lines/rate-limit segments
4. Adds a cached git branch check (5s TTL) if the working directory is a repo
5. Joins everything with configurable separators

See the [official statusLine docs](https://code.claude.com/docs/en/statusline)
for the full JSON schema Claude Code provides.

## License

MIT — see [LICENSE](LICENSE).
