# Claude Breathe

Menu-bar app for macOS. When Claude Code has been working for a while, a full-screen breathing overlay appears; it fades out at the end of the current breath once Claude is done, and drops instantly if Claude needs your attention.

## Xcode setup

The `breathe` target is already configured: macOS only, App Sandbox off (the hook server needs to bind a port), and `LSUIElement = YES` so there is no Dock icon. Run it from Xcode. A wind icon appears in the menu bar; "Test overlay" shows the animation without Claude.

## Claude Code hooks

Add to `~/.claude/settings.json` (merge with any existing `hooks` block):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "curl -s -m 1 -X POST http://127.0.0.1:4466/working >/dev/null 2>&1 || true" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "curl -s -m 1 -X POST http://127.0.0.1:4466/idle >/dev/null 2>&1 || true" } ] }
    ],
    "Notification": [
      { "hooks": [ { "type": "command", "command": "curl -s -m 1 -X POST http://127.0.0.1:4466/attention >/dev/null 2>&1 || true" } ] }
    ]
  }
}
```

`-m 1 || true` makes curl give up after a second and exit cleanly if the app isn't running, so Claude Code is never slowed down or shown a hook error. Hooks in the user settings file apply to Claude Code in the VS Code extension as well as the terminal. Check the hooks reference if the event names have changed: https://code.claude.com/docs/en/hooks.md

## Behaviour

- `working` starts a timer (default 2 s, changeable from the menu). The overlay only shows if Claude is still busy when it fires.
- `idle` cancels a pending timer, or if the overlay is up, lets the current 11 s breath finish and fades out.
- `attention` hides immediately so a permission prompt is never hidden behind the overlay.
- Esc or click dismisses. Focus is handed back to the app that was frontmost before (VS Code).

## Known limits / next steps

- Covers the main screen only. For multiple displays, create one `OverlayWindow` per `NSScreen.screens` entry and share the same `BreathClock`.
- If you run several Claude Code sessions at once, their events interleave. The hook JSON on stdin contains `session_id`; pipe it through (`curl --data-binary @-`) and track a set of active sessions if that becomes a problem.
- `NSApp.activate` steals focus so Esc works. If you'd rather the overlay never take focus, set `ignoresMouseEvents = true`, skip activation, and use a global `NSEvent.addGlobalMonitorForEvents` for the Esc key instead (requires Accessibility permission).
