#!/usr/bin/env python3
"""Regenerate docs/images/*.svg from statusline.sh's real ANSI output.

These aren't hand-drawn mockups — each SVG is rendered from the script's
actual stdout for a fixed mock JSON payload, so the previews can't drift
out of sync with the script. Re-run this after any change to statusline.sh.

Requires: pip install rich
"""
import os
import subprocess

from rich.console import Console
from rich.terminal_theme import TerminalTheme
from rich.text import Text

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "statusline.sh")
OUT_DIR = os.path.join(REPO, "docs", "images")

# GitHub's dark-mode palette, so the SVG blends into a README on github.com
GITHUB_DARK = TerminalTheme(
    (13, 17, 23),
    (201, 209, 217),
    [
        (13, 17, 23), (255, 123, 114), (126, 231, 135), (255, 199, 95),
        (121, 192, 255), (255, 123, 235), (86, 216, 216), (201, 209, 217),
    ],
)

SCENARIOS = {
    "normal": {
        "title": "Normal — 42% context",
        "json": '''{
  "model": {"display_name": "Sonnet 4.6", "id": "claude-sonnet-4-6"},
  "context_window": {"used_percentage": 42, "context_window_size": 200000},
  "cost": {"total_cost_usd": 1.23, "total_duration_ms": 185000,
           "total_lines_added": 156, "total_lines_removed": 23},
  "rate_limits": {"five_hour": {"used_percentage": 12}, "seven_day": {"used_percentage": 8}},
  "workspace": {"current_dir": "%s"}
}''' % REPO,
    },
    "warning": {
        "title": "Warning — 75% context",
        "json": '''{
  "model": {"display_name": "Opus 4.6", "id": "claude-opus-4-6"},
  "context_window": {"used_percentage": 75, "context_window_size": 1000000},
  "cost": {"total_cost_usd": 12.50, "total_duration_ms": 4500000,
           "total_lines_added": 340, "total_lines_removed": 85},
  "rate_limits": {"five_hour": {"used_percentage": 60}, "seven_day": {"used_percentage": 22}},
  "workspace": {"current_dir": "%s"},
  "worktree": {"name": "my-feature"}
}''' % REPO,
    },
    "danger": {
        "title": "Danger — 92% context",
        "json": '''{
  "model": {"display_name": "Sonnet 4.6", "id": "claude-sonnet-4-6"},
  "context_window": {"used_percentage": 92, "context_window_size": 200000},
  "cost": {"total_cost_usd": 0.85, "total_duration_ms": 60000,
           "total_lines_added": 0, "total_lines_removed": 0},
  "rate_limits": {"five_hour": {"used_percentage": 88}, "seven_day": {"used_percentage": 40}},
  "workspace": {"current_dir": "%s"}
}''' % REPO,
    },
    "startup": {
        "title": "Startup — clean slate",
        "json": '''{
  "model": {"display_name": "Claude"},
  "context_window": {"used_percentage": 0, "context_window_size": 0},
  "cost": {"total_cost_usd": 0, "total_duration_ms": 0,
           "total_lines_added": 0, "total_lines_removed": 0},
  "rate_limits": {},
  "workspace": {"current_dir": "%s"}
}''' % REPO,
    },
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    env = os.environ.copy()
    env["COLORTERM"] = "truecolor"

    for name, spec in SCENARIOS.items():
        result = subprocess.run(
            [SCRIPT], input=spec["json"], capture_output=True, text=True, env=env, cwd=REPO,
        )
        raw = result.stdout.rstrip("\n")
        text = Text.from_ansi(raw)

        console = Console(record=True, width=text.cell_len + 2, file=open(os.devnull, "w"))
        console.print(text)
        svg = console.export_svg(title=spec["title"], theme=GITHUB_DARK, font_aspect_ratio=0.55)

        out_path = os.path.join(OUT_DIR, f"{name}.svg")
        with open(out_path, "w") as f:
            f.write(svg)
        print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
