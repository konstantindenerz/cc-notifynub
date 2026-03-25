#!/usr/bin/env bash
#
#    ▄▄▄▄▄
#   █ ▲ ▲ █  NotifyNub
#   █ ▄▄▄ █  Claude Code notification
#   ▀▀▀▀▀▀▀
#
# Reads hook JSON from stdin; falls back to positional args
SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# --- Renderer (runs inside tmux popup) ---
if [[ $1 == "--render" ]]; then
  state="${NOTIFY_STATE:-idle}"
  win="${NOTIFY_WIN:-}"
  win_idx="${NOTIFY_WIN_IDX:-0}"
  label="${NOTIFY_LABEL:-...}"

  lt=$'\033[38;2;175;172;165m'  md=$'\033[38;2;90;88;82m'
  dk=$'\033[38;2;42;40;36m'     tx=$'\033[38;2;205;203;198m'
  ac=$'\033[38;2;205;117;85m'   dm=$'\033[38;2;120;118;112m'
  r=$'\033[0m'

  case $state in
    done)
      face="${lt}█${ac} ▲ ▲ ${lt}█${r}"
      mouth="${lt}█${md} ${ac}▄▄▄${md} ${lt}█${r}" ;;
    permission)
      face="${lt}█${ac} ▓ ▓ ${lt}█${r}"
      mouth="${lt}█${md}  ${lt}▄${md}  ${lt}█${r}" ;;
    *)
      face="${lt}█${md} ▒ ▒ ${lt}█${r}"
      mouth="${lt}█${md} ───  ${lt}█${r}" ;;
  esac

  printf "\n"
  printf "  ${dk}░${lt}▄▄▄▄▄${dk}░${r}\n"
  printf "  %s  ${dm}[%s]${r}\n"                    "$face" "$win"
  printf "  %s  ${tx}CC ${ac}·${r} ${tx}%s${r}\n"  "$mouth" "$label"
  printf "  ${lt}▀▀▀▀▀▀▀${dk}░${r}\n"

  tput civis

  # Enter -> jump to window, q -> close, others ignored
  jump() { tmux select-window -t ":$win_idx"; exit 0; }

  [[ $state == "permission" ]] && timeout=10 || timeout=5

  deadline=$(( SECONDS + timeout ))
  while (( SECONDS < deadline )); do
    remaining=$(( deadline - SECONDS ))
    (( remaining < 1 )) && remaining=1
    read -t "$remaining" -rsn1 k || exit 0
    [[ $k == "" ]] && jump
    [[ $k == "q" ]] && exit 0
  done
  exit 0
fi

# --- Test mode ---
if [[ $1 == "--test" ]]; then
  case "${2:-done}" in
    permission) echo '{"hook_event_name":"Notification","message":"Permission to use Bash","notification_type":"permission_prompt"}' | NOTIFY_FORCE=1 exec "$SCRIPT" ;;
    *)          echo '{"hook_event_name":"Stop","stop_hook_active":false}' | NOTIFY_FORCE=1 exec "$SCRIPT" ;;
  esac
fi

# --- JSON helpers (no jq needed) ---
json_val() { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
json_bool() { echo "$1" | grep -q "\"$2\":true"; }

# --- Dispatcher ---
# Read stdin (JSON from Claude Code hooks) with timeout to prevent blocking
input=""
if [[ ! -t 0 ]]; then
  read -t 1 -d '' input 2>/dev/null || true
fi

hook=$(json_val "$input" "hook_event_name")

case $hook in
  Stop)
    json_bool "$input" "stop_hook_active" && exit 0
    state="done"
    label="DONE"
    ;;
  Notification)
    state="permission"
    msg=$(json_val "$input" "message")
    # Extract tool name: "...to use Bash" -> "Bash?"
    if [[ $msg =~ to\ use\ (.+) ]]; then
      label="${BASH_REMATCH[1]}?"
    else
      label="APPROVE?"
    fi
    ;;
  *)
    # Fallback: positional arg (done/permission)
    [[ ${1:-done} == "permission" ]] && state="permission" || state="done"
    [[ $state == "done" ]] && label="DONE" || label="APPROVE?"
    ;;
esac

# Outside tmux: macOS notification
if [[ -z "$TMUX" ]]; then
  osascript -e "display notification \"$label\" with title \"Claude Code\" sound name \"default\""
  exit 0
fi

# Skip if Claude window is active (bypass with NOTIFY_FORCE=1)
if [[ -z "$NOTIFY_FORCE" && $state != "permission" \
   && $(tmux display-message -t "$TMUX_PANE" -p '#{window_active}') == 1 ]]; then
  exit 0
fi

win=$(tmux display-message -t "$TMUX_PANE" -p '#I:#W')
win_idx=${win%%:*}
[[ $state == "permission" ]] && pw=34 || pw=38

tmux display-popup \
  -x R -y T -w "$pw" -h 7 \
  -b rounded \
  -s "fg=#9E8C5D,bg=#262626" \
  -S "fg=#9E8C5D" \
  -e "NOTIFY_STATE=$state" \
  -e "NOTIFY_WIN=$win" \
  -e "NOTIFY_WIN_IDX=$win_idx" \
  -e "NOTIFY_LABEL=$label" \
  -E "clear; bash '$SCRIPT' --render"
