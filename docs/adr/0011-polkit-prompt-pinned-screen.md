# The polkit prompt pins to the request-time screen

## Status

accepted — deviates from the grilled spec (2026-11-07) on one point: the
bar is shown on the pinned screen while the prompt is open, not hidden;
the spec's own placement clause contradicts its "bar hides" wording
(below).

## Context

`PolkitPrompt` is the only `PanelBase` with no `panelName`: nothing in the
`Panels` registry, so its per-screen visibility cannot ride
`Panels.panel`/`Panels.screenName` the way a normal menu's does — it gates
on `externalRequested` instead. Before this change that gate was live
focus: `Polkit.active && Hypr.focusedScreenName === screenId`, so a focus
change mid-auth (launching the very thing that asked for the password, a
stray focus dispatcher, a window closing) teleported the open,
exclusive-focus prompt to another screen while the user was typing into
it. Other external surfaces follow focus live (the OSD's
`Hypr.focusedScreenName === screenId`), and ordinary panels re-target on
every open — but a credential dialog is the one surface where a mid-flow
move is actively harmful: the user's keystrokes and attention are already
committed to one screen.

## Decision

The `Polkit` singleton pins the prompt to the screen that had focus when
the auth request arrived, for the whole flow:

- `services/Polkit.qml` captures `targetScreen = Hypr.focusedScreenName`
  in `PolkitAgent.onFlowChanged` when a new flow object appears, and
  clears it when the flow goes null. The quickshell auth flow object
  persists across failure re-prompts, so a wrong password never
  re-captures: the prompt stays put through submit → fail → re-prompt.
- The per-screen gate becomes
  `externalRequested: Polkit.active && Polkit.pinScreen === screenId`
  (`panels/PolkitPrompt.qml`). `pinScreen` resolves `targetScreen`
  through `Quickshell.screens` and falls back to the live focused screen
  when the pinned monitor is no longer connected, so a hotplug mid-auth
  cannot strand the prompt on a dead output.
- A new auth request is a new flow object, hence a fresh capture at the
  then-focused screen.
- The bar stays visible on the pinned screen while the prompt is up: the
  `menuOpen` expression in `bar/Bar.qml` gains
  `|| (Polkit.active && Polkit.pinScreen === screen.name && !Hypr.fullscreen(...))`,
  the same treatment every attached menu gets.

**Spec deviation — bar shown, not hidden.** The grilled spec's placement
clause (`attached: true` under-bar card, concave top corners, slide-down
from the bar) requires the bar: the concave top is `BarSurface` geometry
moulded to the bar's bottom edge, and hiding the bar would leave an
orphaned card with nothing to attach to. The spec's "the bar hides on the
pinned screen while the prompt is open" clause contradicts that placement
clause within the same document; the implementation resolves it in favour
of the placement clause and shows the bar on the pinned screen.

## Considered options

- Live follow-focus (status quo ante): rejected — an exclusive-focus
  credential prompt that jumps mid-typing is the failure mode this ADR
  exists to remove.
- Re-capture on each re-prompt: rejected — a re-prompt is not a new
  request; re-capturing would let a focus change made during the failure
  delay move the prompt the user is already typing into.
- Route the pin through `Panels`/`panelName`: rejected — it would make
  the prompt a menu in the registry, entangling an agent-initiated auth
  request with the user-initiated toggle paths, ESC dismiss and the
  panel-width cluster metrics, none of which apply.
- Hide the bar on the pinned screen (the spec's literal wording):
  rejected — see the deviation above.

## Consequences

The prompt ignores focus changes for the life of one auth request; it
moves at most once per flow, and only if the pinned screen disconnects
(fallback to the focused screen — the old behaviour, as an availability
compromise rather than a preference). The `lastFlow` identity guard keeps
the capture keyed to real flow objects; the test seam's fake flow sets
`targetScreen` directly (`polkitShow <screen>`), so `polkitState` can
assert `targetScreen`/`pinScreen` without a real `pkexec`. New auth
requests re-pin, so the rule never outlives the request that set it.
