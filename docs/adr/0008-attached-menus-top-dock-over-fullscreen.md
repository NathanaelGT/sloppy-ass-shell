# Attached menus top-dock over fullscreen

Hyprland alpha-hides top-layer surfaces whenever the monitor's active
workspace has a fullscreen window, so an attached menu opened over a
fullscreen app would leave a blank strip where the bar should fuse to it —
and any attached menu on the top layer would be invisible outright (only
exclusive-focus panels like the launcher, already on the overlay layer, stay
visible). Instead of leaving the gap, attached menus switch to the
**top-docked** mode: they dock flush to the screen's top edge on the overlay
layer, repositioning live as fullscreen toggles.

## Considered options

- **Always-overlay**: putting every attached menu on the overlay layer
  permanently — rejected: it would stack shell surfaces above the lock
  screen and OSD ordering without needing to; the layer bump only matters
  while fullscreen hides the top layer.
- **Move menus up, keep top layer**: rejected — the menu itself would still
  be alpha-hidden; only the offset would be fixed.

## Consequences

- The concave top shape is kept while top-docked: the menu reads as fused to
  the screen edge, which is deliberate even though no bar is rendered there.
- The bar's menu-open force-show is a no-op under fullscreen (compositor
  hides it regardless), so the bar is simply left hidden.
- Fullscreen state is judged on true fullscreen (hyprctl fullscreen mode 1)
  per screen's active workspace, not on maximized windows, which still
  respect the bar's exclusive zone.
