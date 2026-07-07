#!/bin/bash
# Quick tester for statusline.sh — feeds mock Claude Code session JSON
# through the real script (including the jq call) so you can see it
# rendered in your actual terminal before wiring it into settings.json.
#
# Usage:
#   chmod +x test-mock.sh
#   ./test-mock.sh            # all scenarios
#   ./test-mock.sh normal     # just one
#   ./test-mock.sh warning
#   ./test-mock.sh danger
#   ./test-mock.sh startup

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/../statusline.sh"

normal='{
  "model": {"display_name": "Sonnet 4.6", "id": "claude-sonnet-4-6"},
  "context_window": {"used_percentage": 42, "context_window_size": 200000},
  "cost": {"total_cost_usd": 1.23, "total_duration_ms": 185000,
           "total_lines_added": 156, "total_lines_removed": 23},
  "rate_limits": {"five_hour": {"used_percentage": 12}, "seven_day": {"used_percentage": 8}},
  "workspace": {"current_dir": "'"$DIR"'"},
  "agent": {"name": ""}
}'

warning='{
  "model": {"display_name": "Opus 4.6", "id": "claude-opus-4-6"},
  "context_window": {"used_percentage": 75, "context_window_size": 1000000},
  "cost": {"total_cost_usd": 12.50, "total_duration_ms": 4500000,
           "total_lines_added": 340, "total_lines_removed": 85},
  "rate_limits": {"five_hour": {"used_percentage": 60}, "seven_day": {"used_percentage": 22}},
  "workspace": {"current_dir": "'"$DIR"'"},
  "worktree": {"name": "my-feature"}
}'

danger='{
  "model": {"display_name": "Sonnet 4.6", "id": "claude-sonnet-4-6"},
  "context_window": {"used_percentage": 92, "context_window_size": 200000},
  "cost": {"total_cost_usd": 0.85, "total_duration_ms": 60000,
           "total_lines_added": 0, "total_lines_removed": 0},
  "rate_limits": {"five_hour": {"used_percentage": 88}, "seven_day": {"used_percentage": 40}},
  "workspace": {"current_dir": "'"$DIR"'"}
}'

startup='{
  "model": {"display_name": "Claude"},
  "context_window": {"used_percentage": 0, "context_window_size": 0},
  "cost": {"total_cost_usd": 0, "total_duration_ms": 0,
           "total_lines_added": 0, "total_lines_removed": 0},
  "rate_limits": {},
  "workspace": {"current_dir": "'"$DIR"'"}
}'

run_one() {
  label="$1"
  json="$2"
  echo "--- $label ---"
  printf '%s' "$json" | "$SCRIPT"
  echo
}

case "${1:-all}" in
  normal)  run_one "Normal (42%)"  "$normal" ;;
  warning) run_one "Warning (75%)" "$warning" ;;
  danger)  run_one "Danger (92%)"  "$danger" ;;
  startup) run_one "Startup (0%)"  "$startup" ;;
  all|*)
    run_one "Normal (42%)"  "$normal"
    run_one "Warning (75%)" "$warning"
    run_one "Danger (92%)"  "$danger"
    run_one "Startup (0%)"  "$startup"
    ;;
esac
