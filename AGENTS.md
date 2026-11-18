# AGENTS.md

Hand-written Quickshell 0.3.2 config. NixOS, Hyprland, Catppuccin Mocha, `Theme.scale = 1.25`.

## Testing with me

- Test on **eDP-1** unless told otherwise, and do not move testing to another monitor unless the
  task needs it. The user works on HDMI-A-1, so eDP-1 testing does not disturb them; panel
  instances are per-screen. Look at a `grim` capture; never assert a visual result
  from reading code.
- Prefer the test driver over injected input: after every reload
  `quickshell ipc call test setActive true`. `test openPanel <name>` (defaults to eDP-1) and
  `test panelState` / `test closePanel` cover any menu. Prefer idempotent setters over toggles so
  mid-test user activity cannot invert a step. The driver never moves the cursor or changes
  focus. Per-panel seam reference: `docs/agents/testing.md`.
- Real actions to treat carefully — announce first (`quickshell ipc call notify send <body>
  <urgency>`, urgency `low`/`normal`/`critical`, empty = `normal`) and snapshot/restore what they
  touch: `routeStream`, wifi join/forget, process kills, lock engages, idle Dim/DPMS/Lock.
  Power menu: NO testing, NO driver seams — rows 2-4 are lock&suspend/reboot/shutdown and a
  completed hold executes for real; the user tests it manually. Never arm an idle lock timeout
  you cannot beat; while the session is locked, `shell reload` and `test reloadNow` are REFUSED,
  so never leave watch reloads enabled around a lock test.
- Fall back to input injection (`ydotool`, `wtype`, `dotool`; `/dev/uinput` is writable) only for
  interactions the driver does not cover, and only after notifying the user 2 s beforehand
  (`notify send "about to move the cursor" normal` then sleep 2). The toast closes the focused
  panel (focus steal, 5 s lifetime), so wait it out and reopen the panel before interacting.
  Prefer `dotool` (`ydotoold` is broken here); `mousemove X Y` is RELATIVE (deltas), aim with
  `mouseto X Y` (0.0–1.0 fractions of the 3840x1080 layout) and verify with `hyprctl cursorpos`.
  Re-capture geometry immediately before aiming. Synthetic clicks do NOT grant Hyprland keyboard
  focus to `OnDemand` layer surfaces, so injected typing lands in the focused window, never in a
  panel `TextInput`. Confirm every result with a `grim` capture and state plainly what stayed
  unverified. `test beginWork`/`endWork` already toast session start/end, so a separate done
  notice is only needed for sessions that never armed test mode:
  `notify send "testing done — all yours" low`.
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
  a stuck session (stuck watch-off recovers with `endWork`). `reloadNow false` is a SOFT
  reload: it re-reads child files but NOT the root `shell.qml` — after editing shell.qml use
  `test reloadNow true` (hard), and probe liveness (e.g. a version key in an ipc reply) when
  behavior contradicts the files; after editing `services/*`, prefer `reloadNow true`.
- Toggle once: `quickshell ipc call shell close` then `volumePanel`. Two calls in a row cancel out.
- Cursor shape is invisible to the driver: move the pointer, then `grim -c` with a tight `-g`
  crop. A hover highlight proves delivery, never the cursor. To name a cursor thief, use the
  `QT_LOGGING_RULES` recipe in docs/adr/0014.

## Design decisions to keep

- Concave top corners come from `components/BarSurface.qml`; the bar and the attached menu cards
  share it (see also docs/adr/0016).
  `layer.enabled` clips a subtree to its own rect, so widen the item rather than relying on overflow.
- A `Shape` (CurveRenderer) renders nothing under an ancestor `clip: true` unless its own subtree is
  layered: put `layer.enabled: true` (+ `layer.samples: 4`) on the clipped item itself, as `visual`
  and `concaveLead` in `panels/PanelBase.qml` do.
- Shadow = one `components/PanelShadow.qml` (`QtQuick.Effects.MultiEffect`, hidden source, shadow
  behind) around the card on all sides, tuned by `Theme.shadowPad/shadowBlur/shadowOpacity/
  shadowVerticalOffset`. Same recipe for bar and menus; `layer.effect` clips, so use the hidden-source
  pattern.
- Bar and menus fill with `Theme.base`; inner cards use `Theme.surface`, chips and dropdowns
  `Theme.surfaceHigh`, separator lines `Theme.surfaceHigher`.
- Buttons: `BarButton` (capsule) and `IconButton`; hover `Theme.surfaceHigh`, active `Theme.primary`.
- Interaction convention: left-click opens, right-click performs the same action immediately,
  middle-click restarts the backing service, wheel steps 5 % on the bar and 1 % inside a menu.
  Exceptions: the power menu's destructive rows ignore right-click (Lock right-clicks instantly);
  the bar clock's right-click toggles the alt-time display instead of opening the dashboard.
- All menus are built on `panels/PanelBase.qml` — knobs and the MouseArea.onWheel constraint:
  docs/adr/0016.
- `Behavior` animation properties (`duration`, `easing.type`) freeze after the Behavior's first
  trigger in this Quickshell build: `duration: root.merged ? 140 : 450` inside a Behavior runs
  with whichever branch the FIRST trigger evaluated, forever. Drive
  phase-dependent fades with explicit `NumberAnimation`/`SequentialAnimation` objects restarted
  from the state change (Banner's `splitAnim`/`lobeHideAnim`, Clock's `clockShowAnim`), and keep
  PauseAnimation holds out of Behaviors for the same reason.
- Cursor ownership (docs/adr/0014): Qt takes the cursor from the topmost item that has one, not
  from the item under the pointer, and a bare `MouseArea` has `Qt.ArrowCursor`. So nothing
  full-surface may sit above interactive content — in `panels/PanelBase.qml` the press catcher
  and the wheel catcher stay below `headerArea`/`scroller`. Buttons and clickable rows set
  `cursorShape: Qt.PointingHandCursor`; plain `Item` overlays (`overlayArea`, `keyCatcher`,
  `layer.effect`) claim nothing and are safe.
- Anything that must outlive a restart lives in `~/.local/state/quickshell/*.json`;
  `PersistentProperties` only survives reloads. Exception: notification history is
  `~/.local/state/quickshell/notifications.db`, SQLite driven through the `sqlite3` CLI
  (docs/adr/0004) — the one state file that is not JSON.
- Arrivals display as the Banner pinned to eDP-1 (docs/adr/0005, docs/adr/0012); its state
  machine lives in `services/Notifs.qml`.
- PipeWire stream facts: `properties["pulse.corked"]` means paused, `object.serial` is the
  per-instance identity, `application.icon-name` carries a `-symbolic` suffix to strip, and the app
  icon resolves from the toplevel appId/`class` through `services/AppIcons.qml` (desktop entry icon).
- `PwNode.properties` is invalid unless the node is bound with `PwObjectTracker`.
- Reuse before rewriting: `BarSurface`, `Slider`, `EditablePercent`, `EditableLabel`, `MuteButton`,
  `VolumeIcon`, `SectionHeader`, `PlaceholderCard`, `Pins`, `Aliases`, `Audio`.
- Launcher providers (docs/adr/0015): one file in `providers/` + one registry line in
  `services/Providers.qml`; providers are stateless, the launcher owns the per-provider session.
- Music: Folders tab is a single drill-down browser (docs/adr/0001); Queue and Folders track cards
  share one design (docs/adr/0002) — the two delegates in `panels/MusicPanel.qml` mirror each
  other's metrics and must be kept in sync by hand.

## Style

- 2-space indent, no comments, `id: root`, functions before the markup.
- `panels/` screens, `components/` reusable items, `services/` singletons, `providers/` launcher
  providers, `theme/` tokens.
- Prefer `Column`/`Flickable` over `ListView`; the notification history list is the one exception.
  Quickshell 0.3.2 models are `ObjectModel` — read `.values`.
- Format as the last step of the task, after the behavior checks: `find . -name '*.qml' | sort >
  /tmp/opencode/qmlformat-files.txt` then the `qmlformat` binary under `/nix/store/*qtdeclarative-6*/bin`
  with `-F /tmp/opencode/qmlformat-files.txt` (in-place, whole tree, idempotent; the root
  `.qmlformat.ini` pins 2-space indent and essential semicolons). It lands after verification, so the
  formatted file is never the version that was behavior-checked and only goes live on the next reload.
- Always brace control-flow bodies (`if`/`else`/`for`/`while`), even when the body is a single statement;
  `else if` chains stay chained.
- Report every finding with severity and a `file:line` proof; ask before assuming; keep edits
  surgical; propose extra features instead of adding them; never commit.

## Agent skills

### Issue tracker

Local markdown: issues live as files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Defaults: the five canonical roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.
