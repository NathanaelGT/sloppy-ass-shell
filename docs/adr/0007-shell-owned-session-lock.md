# The shell takes over the session lock

## Status

accepted — the capture-blur background and the ext-session-lock surface
are superseded by [0008](0008-live-lock-blur.md); the PAM, trigger-file and
shell-owned-lock decisions stand

## Context

Locking the session meant spawning hyprlock: a separate process with its own
look, its own configuration, and no access to the shell's theme, fonts or
test driver — the lock screen was the one full-screen surface the user saw
daily that the shell did not draw. The power menu already had a Lock row and
notifications already tracked a Locked flag (glossary), but the lock itself
was foreign. Authentication was the harder half: on this NixOS `/etc/pam.d`
is generated read-only, and the stock login stack there references a
nonexistent `system-auth`, so even keeping hyprlock meant its PAM service
was never locally editable.

## Decision

The shell owns the session lock (glossary: Locked). On request — SUPER+L
(wired to the shell's lock IPC), the power menu's Lock row (instant, no
hold), or Lock & Suspend — it first captures every screen, then raises its
own ext-session-lock surface on each screen. The lock screen (glossary:
Lock screen) shows the pre-lock desktop — blurred in the capture pipeline
and dimmed by a 30 % scrim, faded in over the theme base colour — under the
clock and password field; if a capture fails or times out, the lock still
engages over the flat base colour. A test-only preview on eDP-1 runs the
same screen and the same real password check without ever taking the lock.

Authentication goes through Quickshell's PamContext against a repo-shipped
`pam.d/quickshell` service of `pam_unix`. The repo ships its own service
config because `/etc/pam.d` is generated read-only on this NixOS and the
host login stack references a nonexistent `system-auth`; self-authentication
still works because the setuid `unix_chkpwd` wrapper answers for the
invoking user's own password. Input is accepted only after the compositor
confirms the lock is secure, and the surface paints the theme base colour
from its first frame so no desktop frame flashes through.

## Considered options

- Keep hyprlock: rejected — a second lock stack with a second look and no
  seams into the shell's theme, test driver or notification state; the
  capture-based background would have been impossible.
- Add a PAM service through a NixOS `security.pam.services` rebuild:
  rejected — a system rebuild to maintain a config the repo can ship itself,
  and the lock's authentication would live outside this repository.
- Blur in QML with `MultiEffect` instead of in the capture pipeline
  (grim → ffmpeg scale-down + boxblur + upscale): rejected — MultiEffect's
  blur was too weak at full-screen scale, and its `blurEnabled` gate
  silently disabled rendering; the capture pipeline bakes the blur into the
  stored PNG, so the surface has nothing to compute per frame.
- Wait for the lock to become secure before suspending (Lock & Suspend):
  rejected — suspending is the user's declared intent; see consequences.

## Consequences

There is no unauthenticated unlock path: the unlock is reachable only from
a PAM success, and no IPC or test seam can clear the lock without a correct
password. The flip side is fail-open: if the shell dies, or a live
watched-file reload runs while locked, the compositor unlocks the session
because the lock surface died with the shell. That is the accepted
trade-off — an unlock, never a trap — and it is why explicit reloads
(`shell reload`, `test reloadNow`) are refused while locked while a watched
reload cannot be refused, so watch reloads must stay off around lock tests.

Lock & Suspend suspends even if the lock failed to engage: capture → engage
→ suspend run back-to-back with no wait for the lock to settle, and the
suspend is unconditional, so the lock is simply already up at resume.

The session's logind LockedHint is synced with the lock via
`Session.SetLockedHint`, because `loginctl lock-session` does not set the
hint on this logind and hypridle listeners read it; the hint is cleared at
shell startup so a stale `locked` from a crash does not linger. Arrivals
while locked skip the Banner and go straight to History, matching the
existing Locked gating.

The session lock lives in `shell.qml`, not in the lock-state singleton:
declared inside the singleton, the import cycle broke surface instantiation
and the lock failed open. Per-screen captures are overwritten in
`~/.local/state/quickshell/lock/` (one file per screen, refreshed every
lock, no accumulating files) with a 2 s timeout per capture step and a 5 s
overall timeout; a failed or timed-out capture falls back to the flat theme
base. hyprlock stays installed as a manual fallback with its config
untouched, and the dormant hypridle configs invoke the shell's lock IPC
instead of hyprlock.
