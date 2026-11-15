# The Banner renders in its own overlay-layer window

## Status

accepted; supersedes the bar-window headroom and input-mask rules of
ADR-0005's Consequences.

## Context

The banner used to render inside the bar window, which reserved constant
headroom (`barThickness + shadowPad + bannerMaxExpand`) because layer windows
never re-render below their initial height. Panel windows are separate layer
surfaces on the same **top** layer (`aboveWindows: true` maps to top, not
overlay), and Hyprland stacks same-layer surfaces by map order — a panel
opened after startup maps above the bar window, so an arriving banner's
expansion drew behind the open menu card (e.g. the battery panel, whose wide
card overlaps the centered banner region). Layer shell has no restack
request, and moving the bar window to the overlay layer would keep the bar
visible over fullscreen toplevels, which ADR-0008 deliberately avoids.

## Decision

The banner moves out of the bar window into a dedicated `bar/BannerWindow.qml`
per screen, pinned to the **overlay** layer (`WlrLayershell.layer`). Overlay
strictly renders above the top layer regardless of map order, so the banner —
surface and content — now draws above every panel window. The window is
full-width, top-anchored, `barThickness + bannerMaxExpand` tall, maps only
while a banner is up (`visible: laptop && Notifs.bannerVisible &&
!Hypr.fullscreen(screenId)` — preserving ADR-0005's invisible-during-
fullscreen behavior, since the bar used to be alpha-hidden there), and
unmaps when the banner retreats. Lock/OSD/polkit keep precedence naturally:
they are overlay surfaces mapped later than the banner window.

Cross-window wiring flows through `Panels` (the existing cluster-metrics
channel): the bar pushes `bannerMetrics` (`bellRestX`, `clockWidth`,
`bellWidth`, `hovered`), the banner window pushes `bannerBell` back
(`hovered`, `separation`, `expand`, `lobeOpacity`).
The blob's left column — the lobe behind the bell pill plus its expansion
slice — renders in the **bar window** behind the bell widget (a rounded
outline split across two windows leaves corner notches at the seam), driven
per-frame by the pushed values; no side panel card reaches that column (they
start right of it), so the bar window is safe for it. The banner window paints
everything from the bell's right edge onward — the clock-side lobe, the
expansion surface, all content, and the docked app icon, which overhangs the
bell pill's right edge and therefore must draw above the clock-side lobe
(from the bar window the lobe covers it; the icon carries its own
show/hide/dock/shake animations, previously on the bell). The bar gates the
pushed values to defaults whenever the banner is hidden so an unmapped window
can never leave the lobe fused or visible. The banner window's input mask
covers only the compact summary strip and the expanded detail area — bell
clicks fall through to the bar window, keeping the bell interactive
throughout.

The bar window keeps its constant `bannerMaxExpand` headroom — the bell-area
lobe extends with the expansion and the bar window clips at its surface
height — but its mask loses the banner region and stays strip-only;
`shotBar`/`barRect` are unchanged. The banner
registers under the same `"banner"` test key from its own window (window-local
coordinates equal screen coordinates), so `bannerShot`/`panelRect` seams are
unchanged except that `bannerMetrics` (the test seam) no longer reports
`leftLobeOpacity`.

## Considered options

- Raise the bar window above panels: rejected — same-layer stacking has no
  restack request, and putting the bar on the overlay layer would show the
  bar over fullscreen toplevels (ADR-0008).
- Suppress the banner while a side panel is open: rejected — the user wants
  arrivals visible, not hidden; suppression stays limited to center panels.
- Keep the banner in the bar window and remap the bar when a panel opens:
  rejected — remapping flickers and would cut the emergence animation.
- Draw the pill surface in the bar window and only the content in the banner
  window: rejected — the surface below the bar strip would still be covered
  by panel cards, leaving banner text floating without background.

## Consequences

- The banner renders above every open panel (side and center) on eDP-1;
  center-panel suppression and panel-open collapse are unchanged.
- The bell-area lobe lives in `Bar.qml` (`bannerLobe`, `z: -1` behind the
  widgets) while the clock-side lobe lives in the banner window; the two meet
  at the bell's right edge and must be kept geometry-consistent through the
  `Panels.bannerBell` channel.
- Both the bar window and the banner window keep constant
  `bannerMaxExpand` headroom: the bar window because `bannerLobe` extends
  with the expansion, the banner window because it maps per arrival at full
  size.
- The bell widget keeps its original merged visuals (transparent fill,
  seal radii); only the docked app icon moved into the banner window.
