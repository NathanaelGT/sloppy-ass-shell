# The shell owns the idle chain

## Status

accepted

## Context

The session had no idle detection. The dormant `~/.config/hypr/hypridle.conf`
carried an older shape of the idea — brightnessctl dim at 150 s, DPMS off at
300 s — but hypridle is not launched in the active Lua config, and its
listener model has no notion of reversion: it cannot remember which stages
fired, restore per-monitor pre-dim brightness, or gate one stage on another.
Meanwhile the shell already owned every ingredient: the `setIdle` IPC waited
for a real source, `services/Brightness.qml` drives both the internal panel
(brightnessctl) and the external monitor (ddcutil VCP 10), the lock is
shell-owned (docs/adr/0007), and suspend goes through
`LockState.lockAndSuspend()`. Quickshell 0.3.2 ships an `IdleMonitor`
(wayland idle-notify) that can honour idle-inhibit clients.

## Decision

Idle power management lives in the shell as the Idle chain (glossary), one
singleton driven by per-stage `IdleMonitor`s, leaving the hypridle configs
dormant and untouched:

- 3 min: Dim — brightness 0 on every monitor, external (ddcutil) first,
  internal (brightnessctl) last, so the visibly-slow setter goes first and
  both monitors appear to dim together. Pre-dim values are stored per
  display.
- 5 min: DPMS off, globally via the Hyprland dispatcher.
- 5 min 30 s: Lock — the same trigger-file path as SUPER+L, so the lock
  screen and its blur behave identically to a manual lock.
- 1.5 h: Suspend via `lockAndSuspend()` (already locked), behind the Audio
  gate (glossary): suspend waits until no MPRIS audio has played for thirty
  minutes, re-checked on a tick, so a playlist that outlives the deadline
  still suspends thirty minutes after it finishes.

Any input reverts every applied stage: DPMS on and pre-dim brightness
restored. Waking from suspend reverts immediately — monitors on, brightness
back — and if no input follows, the chain re-runs from wake with the full
timeouts. `IdleMonitor.respectInhibitors` is on, so wayland idle-inhibit
clients (e.g. fullscreen video) pause the chain.

The 5 s Idle (glossary) that pauses the notification countdown is the
shortest stage of the same mechanism: the chain, not an external process,
now feeds `Notifs.idle`.

## Considered options

- Revive hypridle as the driver: rejected — its listener scripts cannot
  track applied stages for reversion, cannot share per-monitor brightness
  state with the shell's Brightness service, and offer no test seams; it
  would duplicate state the shell already owns.
- Suspend unconditionally at the deadline: rejected — an overnight playlist
  would be killed mid-listen.
- Never suspend once the deadline passes with audio playing: rejected — a
  finished playlist would keep the machine awake until the user returns.
- Stay dark after wake until the first input: rejected by the user — wake
  should present the lock screen lit, not a black surface.
- Internal monitor only for Dim: rejected — the user works on the external
  monitor; a half-lit desk is not a dimmed session.

## Consequences

Dim and DPMS off are real hardware actions: test runs must be announced
(the `routeStream` convention) and snapshots of brightness state taken and
restored. The Suspend stage is compile-time gated off in test mode — its
only verification is state inspection; a mis-timed test must never suspend
the session. ddcutil's setvcp latency (~1 s per display) is why Dim orders
external before internal. While dimmed, the pre-dim values are authoritative:
a user cannot change brightness mid-Dim (input would have reverted the Dim),
so restore always writes the stored values.

Wake detection is logind's PrepareForSleep; on resume the revert runs
regardless of whether the firmware re-lit the panels. The chain re-arming
from wake means a machine woken unattended re-dims after 3 min, blanks after
5, and suspends again after another 1.5 h — an untouched machine does not
stay lit indefinitely.
