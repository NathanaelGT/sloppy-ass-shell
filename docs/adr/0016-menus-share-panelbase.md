# All menus are built on PanelBase

## Status

accepted

## Context

Ten menus share the same card shape, wheel scrolling and slide animation.
Per-panel reimplementations drift (shadow recipe, dismiss handling, slide
timing), and each drift is a separate bug.

## Decision

All ten menus are built on `panels/PanelBase.qml` (card + Flickable + wheel
scroll + slide). Its knobs: `attached` (concave vs floating rounded, and
hides the bar when a floating one opens), `vertical`/`topMargin`,
`cardWidth`/`maxCardHeight`, `externalRequested`, `exclusiveFocus`,
`dismissOnBackdrop`, `autoFocusKeyCatcher`, `cancelItem` (panel-wide
edit-cancel overlay with an input hole; `VolumePanel` feeds it
`activeNameEditor`, `testDispatch(x, y)` emulates a press for tests).

Floating menus (`attached: false`) use a plain rounded `Rectangle` instead of
`components/BarSurface.qml` (the concave shape belongs to the bar and
attached cards).

Scroll the menu with `MouseArea.onWheel`, not a `WheelHandler` child — a
`MouseArea` consumes the wheel, so the handler never fires.

## Consequences

Behavior fixes land once in PanelBase. New menus start from it rather than
re-deriving the card/wheel/slide stack. `cancelItem`/`testDispatch` are part
of the component's contract, not panel internals.
