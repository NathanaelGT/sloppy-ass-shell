# Arrivals display as a Banner merged into the bar, not a toast stack

## Status

accepted; the single travel-pill geometry and latest-only display are
superseded by ADR-0006, while eDP-1 pinning, suppression and the bar-window
rules still hold.

## Context

Until now an arriving notification popped a stack of up to 5 cards in the
top-right corner of eDP-1 (`notifications/Toasts.qml`, glossary: Toast —
now retired). The stack floated over windows, duplicated the notifications
panel's content, and its geometry was invisible to the bar: the test shot had
to guess the rect from hard-coded margins, and nothing tied the display to
the widget the user already watches. The user wants the arrival to live in
the bar itself: the clock text swaps for the notification, the clock and bell
pills merge into one pill that expands below the bar, and everything reverts
when the display ends.

## Decision

One Banner (glossary) on eDP-1 only, rendered as an overlay pill that emerges
from the bell widget and slides left to cover the clock widget in
`bar/Bar.qml`'s bar area; the bell stays visible and interactive throughout
(badge, DND toggle, dismiss-all), and the clock widget stays put and is
merely covered. The state machine (latest active
notification only, countdown shared with `Notifs.qml`'s 250 ms tick, sticky
capped at 15 s so Critical never hides the clock indefinitely, idle/hover
pause inherited from the record) lives in `services/Notifs.qml`. Spawn is
suppressed while a center/floating panel is open on eDP-1 (dashboard, music,
notifications, launcher, power, window-switcher — anything whose card
overlaps the banner region or hides the bar); side panels (volume, battery,
network, bluetooth) do not suppress. A center panel opened mid-banner
collapses it; the notification itself is untouched (archive/chime rules are
unchanged). While up: the banner pill's left-click opens the notifications
panel and right-click dismisses the notification; the bell keeps its own
handlers.

## Considered options

- Keep the toast stack alongside the banner: rejected — two surfaces for the
  same event; the rework exists to remove the stack.
- Show the banner on every screen's bar: rejected — the user works on
  HDMI-A-1 and must not lose the clock there; eDP-1-only matches the old
  pinning rationale.
- A static pill spanning clock and bell (the first iteration): superseded —
  a pill that travels out of and back into the bell reads better, keeps the
  bell's badge, DND and dismiss-all live throughout, and keeps the banner
  width equal to the clock pill's.
- Morph the Clock/Notifications widgets themselves into the banner: rejected
  — the pills' anchors, hover/click handlers, DND/dismiss seams and the
  cluster metrics the notifications panel attaches to would all have to be
  re-derived mid-morph; a covering overlay keeps the widgets' geometry,
  `Panels.setClusterWidth/Right` and the merge-seal animation untouched.
- Let Critical banners persist until dismissed: rejected — hides the clock
  indefinitely; the 15 s cap reverts the pill while the notification stays
  active.

## Consequences

The bar window keeps a **constant** height (`barThickness + shadowPad +
Theme.bannerMaxExpand`) instead of resizing with the banner: a top-anchored
layer window with an exclusive zone re-commits its larger surface size but
never re-renders below its initial height, so a grown banner simply wasn't
painted — reserved headroom sidesteps that. The bar window also renders
**above** windows (`aboveWindows: true` on both screens): with the old
`aboveWindows: !reserveSpace` it sat *below* toplevels and only the exclusive
zone kept it visible, which made everything the bar painted below the strip —
the banner expansion — disappear behind tiled windows. The input mask gains a
second region over the expanded part so the whole-width strip does not
swallow clicks over the windows below. The bell's unread badge, DND toggle
and merge-seal panel attachment are covered, not removed, while the banner is
up. `toastWindow`/`toastState`/`notifShot` are replaced by
banner-based test seams, and the arrival display is no longer reachable on
HDMI-A-1 at all.
