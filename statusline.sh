#!/bin/bash
# claude-code-statusline (custom build)
# A gradient, information-dense status line for Claude Code.
# Reads session JSON on stdin, prints one formatted line to stdout.
#
# Config via env vars (put in ~/.zshrc or ~/.bashrc):
#   CLAUDE_STATUSLINE_ASCII=1      force plain ASCII, no color/unicode
#   CLAUDE_STATUSLINE_NERDFONT=1   use Nerd Font glyphs
#   CLAUDE_STATUSLINE_POWERLINE=1  use  powerline arrow separators
#   COLORTERM=truecolor            (usually already set) enables 24-bit gradient

set -u

# ---------- environment / capability detection ----------
ASCII_MODE="${CLAUDE_STATUSLINE_ASCII:-0}"
NERDFONT="${CLAUDE_STATUSLINE_NERDFONT:-0}"
POWERLINE="${CLAUDE_STATUSLINE_POWERLINE:-$NERDFONT}"

TRUECOLOR=0
if [ "${COLORTERM:-}" = "truecolor" ] || [ "${COLORTERM:-}" = "24bit" ]; then
  TRUECOLOR=1
fi

RESET='\033[0m'
DIM='\033[2m'

# ---------- color helpers ----------
# 24-bit foreground color
rgb() { printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

# Interpolate green(0,200,83) -> yellow(255,214,0) -> red(255,23,68) at t in [0,100]
gradient_color() {
  t=$1
  [ "$t" -gt 100 ] && t=100
  [ "$t" -lt 0 ] && t=0
  if [ "$t" -le 50 ]; then
    # green -> yellow, local 0..1 over 0..50
    r=$(( 0   + (255 - 0)   * t / 50 ))
    g=$(( 200 + (214 - 200) * t / 50 ))
    b=$(( 83  + (0   - 83)  * t / 50 ))
  else
    tt=$(( t - 50 ))
    r=255
    g=$(( 214 + (23  - 214) * tt / 50 ))
    b=$(( 0   + (68  - 0)   * tt / 50 ))
  fi
  if [ "$TRUECOLOR" = "1" ] && [ "$ASCII_MODE" = "0" ]; then
    rgb "$r" "$g" "$b"
  elif [ "$ASCII_MODE" = "0" ]; then
    # ANSI 256 fallback thresholds
    if   [ "$t" -lt 50 ]; then printf '\033[38;5;46m'
    elif [ "$t" -lt 80 ]; then printf '\033[38;5;220m'
    else                       printf '\033[38;5;196m'
    fi
  fi
}

# ---------- gradient progress bar ----------
# $1 = percentage (0-100), $2 = width in cells (default 12)
progress_bar() {
  pct=$1
  width=${2:-12}
  filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width

  fill_char='█'; empty_char='░'
  [ "$ASCII_MODE" = "1" ] && fill_char='=' && empty_char='-'

  out=""
  i=0
  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then
      pos_pct=$(( (i + 1) * 100 / width ))
      col=$(gradient_color "$pos_pct")
      out="${out}${col}${fill_char}"
    else
      if [ "$ASCII_MODE" = "0" ]; then
        out="${out}${DIM}${empty_char}"
      else
        out="${out}${empty_char}"
      fi
    fi
    i=$((i + 1))
  done
  [ "$ASCII_MODE" = "0" ] && out="${out}${RESET}"
  printf '%s' "$out"
}

# ---------- git branch + dirty (cached 5s) ----------
git_segment() {
  dir="$1"
  [ -z "$dir" ] && return
  cd "$dir" 2>/dev/null || return
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

  cache_key=$(printf '%s' "$dir" | cksum | awk '{print $1}')
  cache_file="/tmp/claude-statusline-git-${cache_key}"
  now=$(date +%s)

  if [ -f "$cache_file" ]; then
    cache_time=$(sed -n '1p' "$cache_file" 2>/dev/null)
    age=$(( now - ${cache_time:-0} ))
  else
    age=999
  fi

  if [ "$age" -ge 5 ]; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    dirty=""
    git diff --quiet 2>/dev/null || dirty="*"
    git diff --cached --quiet 2>/dev/null || dirty="*"
    { printf '%s\n%s\n%s\n' "$now" "$branch" "$dirty"; } > "$cache_file"
  else
    branch=$(sed -n '2p' "$cache_file")
    dirty=$(sed -n '3p' "$cache_file")
  fi

  [ -z "$branch" ] && return
  icon='⎇'
  [ "$NERDFONT" = "1" ] && icon=''
  [ "$ASCII_MODE" = "1" ] && icon='git:'
  printf '%s %s%s' "$icon" "$branch" "$dirty"
}

# ---------- human duration ----------
human_duration() {
  ms=$1
  [ "$ms" -le 0 ] 2>/dev/null && return
  secs=$(( ms / 1000 ))
  h=$(( secs / 3600 ))
  m=$(( (secs % 3600) / 60 ))
  s=$(( secs % 60 ))
  if [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf '%dm%ds' "$m" "$s"
  else
    printf '%ds' "$s"
  fi
}

# ---------- separator ----------
sep() {
  if [ "$ASCII_MODE" = "1" ]; then
    printf ' | '
  elif [ "$POWERLINE" = "1" ]; then
    printf ' %b \033[38;5;240m\033[0m %b' "$DIM" ""
  else
    printf ' %b|%b ' "$DIM" "$RESET"
  fi
}

# ---------- main render, takes the TSV line jq produced ----------
render() {
  line="$1"
  # \x1f (unit separator) is used instead of a real tab: bash's `read` treats
  # tab as IFS whitespace and collapses consecutive tab delimiters, which
  # silently drops empty fields (agent/worktree are usually empty) and
  # shifts every field after them. \x1f is not whitespace, so empty fields
  # are preserved correctly.
  IFS=$'\x1f' read -r MODEL_NAME MODEL_ID CTX_PCT CTX_SIZE COST DURATION_MS \
    LINES_ADDED LINES_REMOVED RL5H RL7D CWD AGENT WT_BRANCH WT_NAME SENTINEL <<EOF
$line
EOF

  MODEL_NAME=${MODEL_NAME:-Claude}
  CTX_PCT=${CTX_PCT:-0}
  CTX_SIZE=${CTX_SIZE:-0}
  COST=${COST:-0}
  DURATION_MS=${DURATION_MS:-0}
  LINES_ADDED=${LINES_ADDED:-0}
  LINES_REMOVED=${LINES_REMOVED:-0}
  RL5H=${RL5H:-0}
  RL7D=${RL7D:-0}

  # strip decimals for integer bash comparisons
  CTX_PCT_INT=${CTX_PCT%%.*}
  RL5H_INT=${RL5H%%.*}
  RL7D_INT=${RL7D%%.*}

  out=""

  # brand diamond
  diamond='◆'
  if [ "$ASCII_MODE" = "1" ]; then
    out="${out}*"
  elif [ "$TRUECOLOR" = "1" ]; then
    out="${out}$(rgb 114 102 234)${diamond}${RESET}"
  else
    out="${out}\033[38;5;99m${diamond}${RESET}"
  fi
  out="${out} ${MODEL_NAME}"

  # context size (only if not already implied by model name, e.g. "1M"/"200k")
  if [ "${CTX_SIZE:-0}" != "0" ]; then
    if [ "$CTX_SIZE" -ge 1000000 ]; then
      size_label="$(( CTX_SIZE / 1000000 ))M"
    else
      size_label="$(( CTX_SIZE / 1000 ))k"
    fi
    case "$MODEL_NAME" in
      *"$size_label"*) : ;; # already shown, skip
      *)
        if [ "$ASCII_MODE" = "1" ]; then
          out="${out} (${size_label})"
        else
          out="${out} ${DIM}(${size_label})${RESET}"
        fi
        ;;
    esac
  fi

  out="${out}$(sep)$(progress_bar "$CTX_PCT_INT" 12) ${CTX_PCT_INT}%"

  # cost — always shown, dim if zero, red if > $10
  cost_disp=$(printf '%.2f' "$COST" 2>/dev/null || echo "0.00")
  dollar='$'
  [ "$NERDFONT" = "1" ] && dollar=''
  if [ "$ASCII_MODE" = "1" ]; then
    out="${out}$(sep)${dollar}${cost_disp}"
  elif [ "$(printf '%.0f' "$COST")" -ge 10 ] 2>/dev/null; then
    out="${out}$(sep)\033[38;5;196m${dollar}${cost_disp}${RESET}"
  elif [ "$cost_disp" = "0.00" ]; then
    out="${out}$(sep)${DIM}${dollar}${cost_disp}${RESET}"
  else
    out="${out}$(sep)\033[38;5;220m${dollar}${cost_disp}${RESET}"
  fi

  # duration — hidden if zero
  dur=$(human_duration "${DURATION_MS%%.*}")
  if [ -n "$dur" ]; then
    if [ "$ASCII_MODE" = "1" ]; then
      out="${out}$(sep)time:${dur}"
    else
      clock='⏱'
      [ "$NERDFONT" = "1" ] && clock=''
      out="${out}$(sep)${clock} ${dur}"
    fi
  fi

  # lines added/removed — hidden if both zero
  if [ "$LINES_ADDED" != "0" ] || [ "$LINES_REMOVED" != "0" ]; then
    if [ "$ASCII_MODE" = "1" ]; then
      out="${out}$(sep)+${LINES_ADDED}/-${LINES_REMOVED}"
    else
      out="${out}$(sep)\033[38;5;46m+${LINES_ADDED}${RESET}/\033[38;5;196m-${LINES_REMOVED}${RESET}"
    fi
  fi

  # git branch + dirty
  git_str=$(git_segment "$CWD")
  [ -n "$git_str" ] && out="${out}$(sep)${git_str}"

  # worktree / agent indicator
  if [ -n "${AGENT:-}" ]; then
    if [ "$ASCII_MODE" = "1" ]; then
      out="${out}$(sep)agent:${AGENT}"
    else
      out="${out}$(sep)⚙ ${AGENT}"
    fi
  elif [ -n "${WT_NAME:-}" ]; then
    if [ "$ASCII_MODE" = "1" ]; then
      out="${out}$(sep)worktree:${WT_NAME}"
    else
      out="${out}$(sep)⚙ worktree:${WT_NAME}"
    fi
  fi

  # rate limits — hidden if zero, red if > 80%
  if [ "$RL5H_INT" -gt 0 ] 2>/dev/null; then
    if [ "$ASCII_MODE" = "1" ]; then
      out="${out}$(sep)5h:${RL5H_INT}%"
    elif [ "$RL5H_INT" -gt 80 ]; then
      out="${out}$(sep)\033[38;5;196m5h:${RL5H_INT}%${RESET}"
    else
      out="${out}$(sep)${DIM}5h:${RL5H_INT}%${RESET}"
    fi
  fi
  if [ "$RL7D_INT" -gt 0 ] 2>/dev/null; then
    if [ "$ASCII_MODE" = "1" ]; then
      out="${out}$(sep)7d:${RL7D_INT}%"
    elif [ "$RL7D_INT" -gt 80 ]; then
      out="${out}$(sep)\033[38;5;196m7d:${RL7D_INT}%${RESET}"
    else
      out="${out}$(sep)${DIM}7d:${RL7D_INT}%${RESET}"
    fi
  fi

  printf '%b\n' "$out"
}

# ---------- entry point ----------
main() {
  input=$(cat)

  tsv=$(printf '%s' "$input" | jq -r '
    [
      (.model.display_name // "Claude"),
      (.model.id // ""),
      (.context_window.used_percentage // 0 | floor),
      (.context_window.context_window_size // 0),
      (.cost.total_cost_usd // 0),
      (.cost.total_duration_ms // 0),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0),
      (.rate_limits.five_hour.used_percentage // 0 | floor),
      (.rate_limits.seven_day.used_percentage // 0 | floor),
      (.workspace.current_dir // .cwd // ""),
      (.agent.name // ""),
      (.worktree.branch // ""),
      (.worktree.name // ""),
      "END"
    ] | join("\u001f")
  ' 2>/dev/null)

  [ -z "$tsv" ] && { printf '◆ Claude\n'; exit 0; }

  render "$tsv"
}

# allow sourcing this file for tests without running main
if [ "${STATUSLINE_TEST_MODE:-0}" != "1" ]; then
  main
fi
