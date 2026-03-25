# cc-notifynub

tmux popup notifications with a pixel-art mascot for Claude Code.

```
   ▄▄▄▄▄
  █ ▲ ▲ █  NotifyNub
  █ ▄▄▄ █  Claude Code notification
  ▀▀▀▀▀▀▀
```

## What it does

Shows a small tmux popup (top-right corner) when Claude Code finishes a task or needs permission to use a tool. The popup features NotifyNub — a tiny mascot with three emotional states.

| State | Eyes | Trigger | Behavior |
|---|---|---|---|
| done | `▲ ▲` | Claude finished | Auto-closes after 5s |
| permission | `▓ ▓` | Tool approval needed | Auto-closes after 10s |
| idle | `▒ ▒` | Default | — |

Outside tmux, falls back to macOS system notifications.

## Install

### As a plugin

```sh
/plugin marketplace add konstantindenerz/cc-notifynub
/plugin install cc-notifynub@cc-notifynub
```

### Manual

Copy `scripts/notify.sh` to `~/.claude/hooks/` and add to `~/.config/claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh done" }] }],
    "Notification": [{ "matcher": "permission_prompt", "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh permission" }] }]
  }
}
```

## Keypress

| Key | Action |
|---|---|
| Enter | Jump to Claude window |
| q | Close popup |
| other | Ignored |

## Smart features

- **Window-aware**: Suppresses "done" notifications when Claude's window is already active
- **Tool name extraction**: Parses hook JSON to show which tool needs approval (e.g. "Bash?" instead of generic "APPROVE?")
- **Stop loop prevention**: Checks `stop_hook_active` to avoid infinite hook cycles

## Testing

```sh
# Test locally with --plugin-dir
claude --plugin-dir ./

# Or run directly
./scripts/notify.sh --test done
./scripts/notify.sh --test permission
```

`NOTIFY_FORCE=1` bypasses the window-active check.

## Dependencies

- tmux 3.5+ (`display-popup -b rounded`)
- bash

## License

MIT
