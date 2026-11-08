# Live lock blur instead of a captured screenshot

## Status

accepted — supersedes [0007](0007-shell-owned-session-lock.md)'s capture-blur
background AND its ext-session-lock surface (the PAM, trigger-file and
shell-owned-lock decisions there stand)

## Context

ADR-0007 locked the screen over a blurred screenshot: grim captured every
screen at lock time and `MultiEffect` GPU-blurred the stored image. The
screenshot freezes the desktop at the moment of locking — a video stops
being visible the instant the lock comes up, and the pipeline carries its
own cost (one `Process` per screen, JPEG encode/decode, a capture-completes
gate before the lock engages). The user wants the real content behind the
lock: what was playing keeps playing, simply blurred.

Hyprland's blur renderer blurs what is rendered *behind* a translucent
layer surface, which is exactly a live blur — the layerrule reaches
layer-shell surfaces. But an ext-session-lock surface is rendered by
Hyprland's lock mode: the compositor stops rendering the normal scene and
the layers entirely and fills the output black under the lock surfaces.
There is no live content behind a session-lock surface, ever (this is why
hyprlock ships a screenshot background). Live blur and the
ext-session-lock protocol cannot coexist on this compositor.

## Decision

The lock is a fullscreen overlay-layer surface per screen
(`lock/LockWindow.qml`, namespace `quickshell-lock`, `keyboardFocus:
Exclusive`), visible while locked — the same mechanism as the eDP-1 test
preview, extended to every screen. A
`layerrule = blur on, match:namespace ^quickshell-lock$` in Hyprland makes
its backdrop — the live windows, videos included — render blurred beneath
it, and its own background is a translucent theme-base tint (60 %) plus the
30 % scrim (`lock/LockBackground.qml`, a pure visual layer with no capture
knowledge). The `WlSessionLock` is removed from `shell.qml`; `LockState`
owns the locked/secure state directly (`secure = true` on engage — input
acceptance no longer waits for a compositor confirmation).

Blur strength is overridden by `LockState` on lock
(`hyprctl eval hl.config({ decoration = { blur = { size = 12, passes = 3 } } })`
— this Hyprland build rejects plain `hyprctl keyword` for config options)
and restored to the global settings values (3 / 1) on unlock. Nothing else
in the setup renders blur, so the override is invisible to everything but
the lock. The preview applies and restores the same override, so it looks
like the real lock.

The capture pipeline is gone: no `grim`, no per-screen `Process`, no
capture map or capture-completes gate. Locking engages immediately on the
trigger; Lock & Suspend engages and suspends back-to-back as before.

## Consequences

The lock shows live, blurred desktop content — video keeps playing under
the lock, and there is no capture latency: the lock is up within a frame of
SUPER+L. The trade-offs:

- The lock is no longer an ext-session-lock surface. Toplevels still
  cannot render above an overlay layer surface, so the lock visually covers
  the whole session; the lost guarantee is that another layer-shell client
  in the session could map above it, and a newly hotplugged output shows
  unblurred desktop until quickshell maps the window on it. Practical risk
  is nil on this machine — every layer-capable client in the session is the
  shell itself. The shell-death fail-open of ADR-0007 is unchanged (the
  compositor keyboard grab dies with the shell, the session stays usable).
- Blurred content is real content. The blur plus tint hides detail but is
  weaker than the old capture blur; the tint/scrim opacities are the tuning
  knobs. This is accepted by design — the user asked for the live backdrop.
- The blur depends on `decoration:blur:enabled` being on. On the
  `onTheGo` specialisation (blur globally disabled) the lock degrades to
  tint-only, the same as every other surface there.
- Blur strength is process-global while locked. Any translucent surface
  that appears later would inherit the lock's stronger blur until unlock.
  On every unlock path (`unlock()` and `closePreview()`, including PAM
  success) `LockState` animates the blur size down to 0 in 50 ms steps
  (~450 ms) in step with the unlock fade-out — a plain restore at the end
  made the backdrop snap from blurred to sharp in one frame — and writes
  the settings values (3 / 1) once the animation completes.
- The trigger file protocol: SUPER+L (and the ipc) writes
  `lock <nanosecond-seq>` to `~/.local/state/quickshell/lock-trigger`; a
  FileView watch parses it and the seq guard ignores anything not newer than
  the last handled seq. Because the guard's counter starts at zero on every
  singleton creation, the first read after startup *primes* the guard —
  records the seq without acting — otherwise a stale trigger file would
  replay the last lock at every shell start or reload (observed twice during
  the 0008 work: a reload self-locked the session). Stale-code caveats
  around reloads are in AGENTS.md (testing), not here.
- Stale capture JPEGs in `~/.local/state/quickshell/lock/` are no longer
  written or read; the directory can be deleted.
