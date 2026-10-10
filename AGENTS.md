# AGENTS.md

Hand-written Quickshell 0.3.1 config replacing a Noctalia 5.2.1 setup. NixOS, Hyprland,
Catppuccin Mocha, `Theme.scale = 1.25`.

## Testing with me

- Test on **eDP-1** unless told otherwise, and do not move testing to another monitor unless the
  task needs it. The user works on HDMI-A-1, so eDP-1 testing does not disturb them; panel
  instances are per-screen. Look at a `grim` capture; never assert a visual result
  from reading code.
- Prefer the test driver over injected input: after every reload
  `quickshell ipc call test setActive true`. `test openPanel <name>` (defaults to eDP-1; pass
  `HDMI-A-1` only when the task needs that screen) and `test panelState` / `test closePanel`
  cover any menu. Prefer idempotent setters over toggles so mid-test user activity cannot invert
  a step: `test setSectionExpanded <section> <true|false>`, `test setAppExpanded <app> <true|false>`.
  Volume flows: `test deviceNames` → `test editorRect`,
  `beginName`/`setDraft`/`dispatch`/`commit`/`cancelEdit`, reading back `volumeState`
  (`dispatch` returns `idle`/`cancelled`/`passthrough`); `toggleSection`/`toggleApp`/
  `pinDevice`/`defaultDevice` mirror the chevron/button handlers (`pinApp` pins a whole app,
  `routeStream <app> <index> <target|Default>` routes audibly — announce first); mute has no
  seam — audible side effects. `test appRows <app>` dumps row keys/labels/pins for deterministic
  assertions without screenshots. It never moves the cursor or changes focus.
- Capture with the driver, not full `grim`: `test panelRect <name>` / `test barRect` return
  screen-absolute geometry; `test shotPanel` / `test shotBar` write a tight crop to
  `/tmp/opencode/test-shot-N.png` — poll `test shotPoll` until `done:true` (one `Process`, no
  blind sleep). Snapshot `audio-aliases.json` AND `audio-pins.json` before `commit`/`pinDevice`/
  `pinApp` tests; restore aliases by re-committing the original text and pins by toggling back.
  Snapshot default sink (`test currentDevice`) and volumes before audible/routing tests
  (`routeStream`, `defaultDevice`, `wpctl`); restore after.
- Fall back to input injection (`ydotool`, `wtype`, `dotool`; `/dev/uinput` is writable) only for
  interactions the driver does not cover, and only after notifying the user 2 s beforehand
  through quickshell's own notification server (`dunstify` is only the sender CLI — dunst itself
  is not used): `dunstify -a opencode -u normal "opencode" "about to move the cursor"` then
  sleep 2, since the user is active on HDMI-A-1. `test beginWork` / `test endWork` already toast
  session start/end the same way, so a separate done notice is only needed for sessions that
  never armed test mode: `dunstify -a opencode -u low "opencode" "testing done — all yours". Run `ydotoold` once for `ydotool`, or pipe commands
  straight to `dotool` (`echo "mousemove 100 0" | dotool`). Synthetic clicks do NOT grant Hyprland
  keyboard focus to `OnDemand` layer surfaces, so injected typing lands in the focused window,
  never in a panel `TextInput`. Confirm every result with a `grim` capture and state plainly what
  stayed unverified.
- Menus open on `Hypr.focusedScreenName`. Pin the monitor with
  `hyprctl dispatch 'hl.dsp.focus({ monitor = "eDP-1" })'` (this Hyprland uses Lua dispatchers;
  `movecursor` is a no-op) and confirm with `hyprctl monitors -j`; ordinary user activity silently
  redirects them mid-test. The test driver takes an explicit screen instead and needs no pinning.
- A config write emits 1–2 reloads, and a reload resets `Panels` (closing any open menu) and reloads
  singletons, disarms the test driver, and resets `Quickshell.watchFiles` to true. The config
  pins it back to false on startup, so live reload is globally off: edits never apply until an
  explicit reload, and hand-edits need `quickshell ipc call shell reload`. Edits made while a
  reload is still in flight can be swallowed by the watcher, so space rapid edits a few seconds
  apart and always finish a batch with an explicit `reloadNow` plus a behavior check — never
  assume the running code matches the files. Wait for the reload to settle before opening a menu,
  then re-arm with `setActive true` if testing. Work sessions use one toggle each way instead:
  `test beginWork` arms the driver and suppresses reload popups (toast confirms);
  work, linting touched files with the `qmllint` binary under
  `/nix/store/*qtdeclarative-6*/bin` before reloading (grep out the import warnings, only
  `error`/`Expected` lines matter); `test reloadNow false` to apply, then re-arm since every
  reload disarms; `test endWork` disarms and toasts. Read `test reloadError` after every reload
  instead of hunting the popup; `test workState` shows armed/watch flags when diagnosing
  a stuck session (stuck watch-off recovers with `endWork`).
- Toggle once: `quickshell ipc call shell close` then `volumePanel`. Two calls in a row cancel out.

## Design decisions to keep

- Concave top corners come from `components/BarSurface.qml`; the bar and the attached menu cards
  share it. Floating menus (`attached: false`) use a plain rounded `Rectangle` instead.
  `layer.enabled` clips a subtree to its own rect, so widen the item rather than relying on overflow.
- Shadow = one `components/PanelShadow.qml` (`QtQuick.Effects.MultiEffect`, hidden source, shadow
  behind) around the card on all sides, tuned by `Theme.shadowPad/shadowBlur/shadowOpacity/
  shadowVerticalOffset`. Same recipe for bar and menus; `layer.effect` clips, so use the hidden-source
  pattern.
- Bar and menus fill with `Theme.base`; inner cards use `Theme.surface`, chips and dropdowns
  `Theme.surfaceHigh`, separator lines `Theme.surfaceHigher`.
- Buttons: `BarButton` (capsule) and `IconButton`; hover `Theme.surfaceHigh`, active `Theme.primary`.
- Interaction convention: left-click opens, right-click performs the same action immediately,
  middle-click restarts the backing service, wheel steps 5 % on the bar and 1 % inside a menu.
- All ten menus are built on `panels/PanelBase.qml` (card + Flickable + wheel scroll + slide). Its
  knobs: `attached` (concave vs floating rounded, and hides the bar when a floating one opens),
  `vertical`/`topMargin`, `cardWidth`/`maxCardHeight`, `externalRequested`, `exclusiveFocus`,
  `dismissOnBackdrop`, `autoFocusKeyCatcher`, `cancelItem` (panel-wide edit-cancel overlay with
  an input hole; `VolumePanel` feeds it `activeNameEditor`, `testDispatch(x, y)` emulates a press
  for tests). Scroll the menu with `MouseArea.onWheel`, not a
  `WheelHandler` child (a `MouseArea` consumes the wheel, so the handler never fires).
- Anything that must outlive a restart lives in `~/.local/state/quickshell/*.json`;
  `PersistentProperties` only survives reloads.
- PipeWire stream facts: `properties["pulse.corked"]` means paused, `object.serial` is the
  per-instance identity, `application.icon-name` carries a `-symbolic` suffix to strip, and the app
  icon resolves from the toplevel appId/`class` through `services/AppIcons.qml` (desktop entry icon).
- `PwNode.properties` is invalid unless the node is bound with `PwObjectTracker`.
- Reuse before rewriting: `BarSurface`, `Slider`, `EditablePercent`, `EditableLabel`, `MuteButton`,
  `VolumeIcon`, `SectionHeader`, `Pins`, `Aliases`, `Audio`.

## Style

- 2-space indent, no comments, `id: root`, functions before the markup.
- `panels/` screens, `components/` reusable items, `services/` singletons, `theme/` tokens.
- Prefer `Column`/`Flickable` over `ListView`; Quickshell 0.3.1 models are `ObjectModel` — read `.values`.
- Report every finding with severity and a `file:line` proof; ask before assuming; keep edits
  surgical; propose extra features instead of adding them; never commit.
