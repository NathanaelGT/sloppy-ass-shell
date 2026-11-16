# The OSD sits flush on the bottom edge and slides inside a mapped-once window

## Status

accepted; supersedes the OSD's floating-pill treatment and its
live-focus screen gate described in ADR-0011's context.

## Context

The OSD was a floating pill inside a `PanelWindow` that mapped per show:
a `16 * scale` bottom margin, a height/2 radius, `Theme.mantle`, and no QML
animation. Its exit was the compositor unmapping the surface — Hyprland
fades layer surfaces on unmap (`layersOut`/`fadeLayers`) and slides and
fades them on map (`layersIn ... slide`), and none of it can be disabled
per surface. A QML slide inside a per-show window therefore composes with
the compositor translating the whole surface: the content would arrive
twice and overshoot. The OSD also followed live focus
(`Hypr.focusedScreenName === screenId`), so a focus change mid-display
teleported it to another monitor.

## Decision

- **Shape**: the card is flush to the screen's bottom edge with concave
  feet, reusing `components/BarSurface.qml` rotated 180° — the bar's
  concave corner language with the rounded convex corners now on top.
  Radius is `Theme.cardRadius` on both ends; the bottom margin is zero.
- **Window**: one `osd/OsdPopup.qml` per screen, mapped once for the
  shell's lifetime on the overlay layer, full width, `implicitHeight` equal
  to the card height. A `slide` property (0 rested, 1 hidden) is animated
  over 220 ms `OutCubic` by explicit `NumberAnimation` objects on show and
  hide; the card's `y` is `slide * height`, so it is clipped by the surface
  below the screen edge. The input mask is the card's bounding box while
  shown or exiting and 0×0 while hidden, so clicks pass through.
- **Pin**: `Osd.show()` records `Hypr.focusedScreenName` as `pinScreen`
  and holds it (`pinHeld`) unless the pin is already held, so a focus
  change while the OSD is up leaves it on its screen. The pinned popup
  calls `Osd.releasePin()` when its fall animation finishes, and that is
  what releases the pin; a show arriving during the exit reverses the slide
  on the same screen. `show()` re-pins when the pinned screen is no longer
  in `Quickshell.screens`.
- A show while visible or exiting only refreshes the content and restarts
  the 2500 ms countdown — it never replays the slide.

## Considered options

- Map per show and run the QML slide inside it: rejected — the compositor's
  `layersIn` slide/fade animates the surface at the same time as the
  content slides inside it, so the entrance would overshoot and wobble.
- Let the compositor's own layer slide be the entrance: rejected — it is
  83 ms and follows the user's Hyprland animation config, and the exit
  would still be the compositor fade this change removes.
- Keep the floating pill and add a slide: rejected — the bottom gap means
  the card cannot emerge from the screen edge.
- Map the window only while shown but keep it resting above the edge:
  rejected — same compositor interference; there is no per-surface
  animation override in layer shell.

## Consequences

- The OSD draws above every top-layer menu through its layer rather than
  map order, and it is now visible over fullscreen windows (top-layer
  surfaces are alpha-hidden there, ADR-0008). It stays beneath the lock
  screen and the polkit prompt, which map later on the same overlay layer.
- A transparent, always-mapped overlay surface exists on every screen; its
  0×0 input region while hidden is what keeps it inert.
- A persistently mapped overlay surface could cost fullscreen direct
  scanout. If that ever matters, moving the window back to the top layer is
  one line; the cost is losing to the later-mapped tall center menus
  (Dashboard, Music, Notifications).
- The entry/exit animation is independent of Hyprland's animation config.
