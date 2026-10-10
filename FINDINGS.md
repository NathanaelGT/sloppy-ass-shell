# FINDINGS

Cumulative findings from building this config (a hand-written Quickshell 0.3.1 replacement for a
Noctalia 5.2.1 setup). Evidence is `path:line` in this repo unless stated otherwise.

**Severity** — HIGH: broken or user-visible failure. MEDIUM: visible defect, unverified requirement,
or a decision worth knowing. LOW: cosmetic, edge case, or note.
**Status** — OPEN / BLOCKED / BY DESIGN / PRE-EXISTING.

---

## 1. Verification constraints

- **V2 — Writers are never the judges of their own visuals. MEDIUM, OPEN.** All visual claims here come
  from `grim` captures plus `magick` crops, not from reading code. Keep that rule.

## 2. Workflow quirks

- **W1 — Reload churn. MEDIUM, OPEN.** Writing a file in the config directory emits one or two
  `Reloading configuration...` events, and a reload rebuilds singletons: `Panels` resets to
  `panel = ""`, so an open menu closes and `PersistentProperties` reload. Confirm the reload settled
  before opening a menu, or the panel can close mid-capture (this repeatedly looked like a bug).
- **W2 — Menus follow the focused monitor. LOW, OPEN.** `Panels.toggle` uses
  `Hypr.focusedScreenName`, so a menu opens on whichever monitor is focused; ordinary user activity
  silently redirects it. Pin the focused monitor with
  `hyprctl dispatch 'hl.dsp.focus({ monitor = "eDP-1" })'` and confirm with `hyprctl monitors -j`
  (moving the cursor does not change focus here).

## 3. Bar

- **B2 — Menu icons strip PipeWire's `-symbolic` suffix. LOW, BY DESIGN.** PipeWire reports
  `com.rafaelmardojai.Blanket-symbolic`; the raw value rendered a monochrome variant, so the icon
  name is now de-suffixed and the toplevel identity (appId/class) is preferred, resolved through
  `services/AppIcons.qml`.
- **B3 — Autohide polls a subprocess. LOW, PRE-EXISTING.** `bar/Bar.qml:47,145` runs
  `hyprctl cursorpos -j` every 250 ms while autohiding, instead of reacting to a pointer event.
- **B4 — The bar fill is `Theme.base`. LOW, BY DESIGN.** Menus now share that fill, so anything drawn
  behind a panel must stay legible against `base`.

## 4. Menus / chrome (`panels/PanelBase.qml`)

- **M2 — Two animations stack. MEDIUM, OPEN.** Hyprland's `animations.conf` already animates layer
  surfaces (`layersIn`/`layersOut` = `slide`, plus `fadeLayers`). Measured: compositor-level animation
  only *fades* an all-anchored full-screen surface — the visible slide is the QML one
  (`panels/PanelBase.qml:156`, 220 ms OutCubic). The window stays mapped 260 ms after close
  (`panels/PanelBase.qml:120`) so the exit animation is not cut off mid-flight.
- **M3 — `layer` bounds clip shape flares. MEDIUM, BY DESIGN (fixed).** `layer.enabled` renders the
  item's subtree into a texture sized to its rect, so the concave top corners were silently cut
  until the container was widened by `shadowPad`/`cornerRadius` on each side
  (`panels/PanelBase.qml:138-147`).
  Any future flare or glow must live inside the layered item's rectangle.
- **M4 — Divide by zero if `maxLevel == 1`. LOW, OPEN (unreachable).**
  `components/VolumeIcon.qml:19`: `overStep = (maxLevel - 1) / 4`. Both call sites pass 1.5.
- **M6 — In-card presses are swallowed; an empty-card click no longer closes. LOW, BEHAVIOUR NOTE
  (revised by M7/M16).** `contentClip`'s wheel `MouseArea` (`panels/PanelBase.qml:230-236`) fills the
  card and accepts presses, so a click on the card's own empty area does nothing; while content
  overflows the Flickable additionally consumes presses to drag (`interactive: contentHeight > height`,
  `:247`). The old "clicking outside the card still closes" is gone — outside input now passes
  through (M7).
- **M7 — Pointer input is clipped to the card. LOW, BY REQUEST (verified; reverses the previous M7).**
  `mask` (`panels/PanelBase.qml:54-60`) sets the surface's input region to the card, so clicks and the
  wheel outside it pass through to the window below. The `backdrop` MouseArea (`:153-161`) and the
  visual click-closer (`:216-218`) are now unreachable (dead). Outside-click closing is replaced by the
  focus-change close (M16); wheel over the card still scrolls the menu through `contentClip`'s MouseArea
  (`:230-236`). Verified with real input on eDP-1: an off-card wheel scrolled the foreground window
  (RMSE 14.6% against a 0 baseline) while the menu stayed open; an off-card click focused that window
  (zen → openchamber) while the menu closed via M16; an in-card click stayed in the card (menu open,
  focus unchanged).
- **M8 — The outer speaker arc overflows its 24 px box by 1-2 px. LOW, BY DESIGN.**
  `components/VolumeIcon.qml:97` (radius 13). Three waves cannot stay legible at Tabler's own 5/9
  radii; items do not clip, so it is invisible today, but any future parent that clips would cut it.
- **M9 — Centered menus slide down from off-screen, not from the bar. LOW, BY DESIGN.**
  `y: root.open ? root.restingY - root.shadowPad : -height` (`panels/PanelBase.qml:150`). For
  `vertical: "center"` (Session, Window switcher, Polkit) the card rests at
  `(screenHeight - cardHeight) / 2` (`panels/PanelBase.qml:61`) and enters from above the screen, so
  it slides down over empty desktop rather than from the bar. Same 220 ms OutCubic as the top menus.
- **M10 — Two migrated panels drifted a few pixels. LOW, BY DESIGN.** Control Center's content padding
  is now PanelBase's 14×scale (was 16×scale), so its card is 4×scale shorter and its tiles ~2×scale
  wider; Window switcher rows are now `parent.width` = `cardWidth − 28×scale` = 392×scale (was
  388×scale). Accepted in exchange for one shared card.
- **M11 — Launcher is now wheel-scrollable. LOW, BY DESIGN.** Its app grid sits inside PanelBase's
  Flickable (`panels/PanelBase.qml:213-231`), so a long result list scrolls; previously the plain
  Grid just grew and the card was capped at 0.7 × screen height (`panels/Launcher.qml:15`). The
  Flickable's `contentY` is not reset when the launcher reopens.
- **M12 — PolkitPrompt's live prompt is untestable here. MEDIUM, OPEN.** `pkexec` is not
  setuid in this environment, so no authentication request can be raised. The migrated chrome was
  verified by temporarily forcing `externalRequested: true` (capture: centered `Theme.base` card,
  concave corners, shadow, Cancel/Authenticate tiles), then reverted. The live flow, input focus and
  submit/cancel remain code-level.
- **M13 — A selectable row's MouseArea sits above its trailing buttons. MEDIUM, PRE-EXISTING
  (confirmed).** In `components/SelectableRow.qml:60-67` the row-level `MouseArea` is the last child,
  i.e. the topmost item, covering the trailing `IconButton`s (Network "forget", Bluetooth
  "remove"/"chevron"). Confirmed with real input on a throwaway harness: clicking the trailing
  `IconButton` fired the row's `clicked` (`PROBE M13 ROW`), not the button's, so those buttons are
  unreachable. Reordering the `MouseArea` under the actions would fix it.
- **M14 — Shadow is now a single all-around MultiEffect. MEDIUM, BY DESIGN.** The six stacked
  downward copies are replaced by `components/PanelShadow.qml` (`QtQuick.Effects.MultiEffect`, hidden
  source, shadow drawn behind the concave/rounded shape) with tokens `Theme.shadowPad`,
  `shadowBlur`, `shadowOpacity`, `shadowVerticalOffset` (`theme/Theme.qml`): a ~3 px downward bias
  and a tight blur, so the bottom is smaller than before. `layer.effect` was rejected because it
  clips the shadow; the hidden-source pattern does not. The bar sits at the screen top, so its top
  shadow is off-screen; left/right only show on the floating HDMI bar.
- **M15 — Floating menus get normal round corners and hide the bar. MEDIUM, BY DESIGN.**
  `attached: false` on Session, Window switcher and Polkit swaps `BarSurface` for a plain rounded
  `Rectangle` (`panels/PanelBase.qml:159-174`); `bar/Bar.qml` `floatingMenuOpen` slides the bar away
  while one is open. On eDP-1 the 56 px `exclusiveZone` stays reserved, so the bar's strip is left
  empty rather than reclaimed by maximised windows. Launcher keeps the bar-attached look.
- **M16 — A menu closes when the active window changes. MEDIUM, BY REQUEST (verified).** `PanelBase`
  snapshots `Hypr.activeWindowAddress` on open (`panels/PanelBase.qml:125`) and closes when it changes
  (`:128-136`); `services/Hypr.qml:9` exposes the address. This replaces outside-click dismissal once
  input is masked (M7). It fires on any active-window change, not only a click — a new window appearing
  or an alt-tab elsewhere closes it; clicking an already-focused window or empty desktop does not (no
  address change). `dismissOnBackdrop` (`:22`) now reads "leave this menu on focus loss" rather than
  backdrop click; Polkit sets it false (`panels/PolkitPrompt.qml:14`) and so stays open. Verified on
  eDP-1: focus zen, open volume, click the openchamber window off-card → active zen→openchamber and the
  menu closed; an off-card wheel kept it open; a click inside the card left both unchanged.

## 5. Volume panel

- **P1 — Per-stream pins are keyed by serial. MEDIUM, BY DESIGN.** The key is
  `application.name|media.name|direction|object.serial` (`panels/VolumePanel.qml:173-176`); that is
  what lets Blanket's three identical "Playback Stream" rows be pinned separately. The pin is orphaned
  if the app tears the stream down and creates a new one — nothing breaks, the row just starts
  unpinned.
- **P3 — "In use" means not corked. LOW, DESIGN NOTE.**
  `properties["pulse.corked"] != "true"` tracks PipeWire's node state (running/idle) and link state
  (active/paused) in this session, but a client that keeps a stream uncorked while silent stays visible.
- **P4 — Device rows opened while current or pinned stay listed. LOW, DESIGN NOTE.** A "sticky"
  visible set (current + pinned) is snapshotted on open (`panels/VolumePanel.qml:79-94`), so changing
  the default never drops a row mid-session. Row *order* is no longer snapshotted — it follows the
  stored device priority (P26).
- **P5 — Both editors cancel on blur/Esc, commit on Enter. LOW, BY DESIGN (verified).**
  `components/EditableLabel.qml:98-102` and `components/EditablePercent.qml:89-93` both call
  `cancel()` on focus loss and Esc, `commit()` on Enter. Grim-verified: typing a draft then
  clicking the card slider reverts the name and leaves the volume untouched; Esc reverts too.
- **P6 — The percent editor keeps a visible `%` and wraps number+suffix in one border. LOW, BY DESIGN
  (verified).** `components/EditablePercent.qml:60-73` is an opacity-faded `Theme.subtext` outline
  around the whole item; the `%` is a separate always-visible suffix, the input right-aligns left of
  it (`components/EditablePercent.qml:78-81`). Grim-verified: border with `%` visible in edit mode,
  typed `6060` clamped to the 150 maximum, Enter commits, Esc cancels.
- **P7 — Master collapse keeps the header and slides away only inactive unpinned cards. LOW, BY
  REQUEST (verified).** `appModel` mirrors `root.appSnapshot` (`panels/VolumePanel.qml:341-365`); each
  card gates `height`/`opacity` with 220 ms height / 160 ms opacity OutCubic
  (`panels/AppGroupCard.qml:188-195`), and which cards survive the collapse is P21's gate.
  Grim-verified: chevron flips to down and inactive unpinned cards slide out while pinned or active
  ones stay.
- **P8 — The app model rebuilds when a stream's route changes. LOW, OPEN.** Each row carries its
  current target, so a route change rebuilds the model and can interrupt an in-progress slider drag.
- **P14 — The route dropdown opens at the window's top-left, not under its chip. MEDIUM, OPEN.**
  `panels/VolumePanel.qml:260-279` positions `routePopup` with
  `anchor.mapToItem(routePopup.parent, ...)`. Probed: for a chip rendered at screen ~(1793,505),
  `anchor.mapToItem(null,0,0)` returns (345,57), so the popup lands at screen ~(206,90) — grim-confirmed
  over the window's top-left — instead of under the chip. Pre-existing (the positioning code predates
  the PanelBase work); injection was needed to see it. `Overlay.overlay` is null here and the window is
  not an Item, so the correct reference still needs identifying.
- **P15 — Attached-menu inset is 40 on HDMI. LOW, BY REQUEST (verified).** `theme/Theme.qml:13`
  (`menuRightInset: 40`, fed into `panels/PanelBase.qml:34`). Grim-compared 25 vs 40 on HDMI-A-1:
  25 leaves a notch/cusp at the bar/menu junction, 40 renders a smooth S-curve.
- **P16 — Collapsed app cards keep the header. LOW, BY REQUEST (verified).** `hasStreams`
  (`panels/AppGroupCard.qml:39`) gates card visibility instead of row visibility, so collapsing hides
  rows but never the whole card. Verified with paused VLC: paused+collapsed card keeps its header.
- **P17 — Empty app list shows an icon + placeholder, zero-height when hidden. LOW, BY REQUEST
  (verified via force-show probe).** `panels/VolumePanel.qml:455-468`: `volume-off` icon plus
  "No apps are playing or recording audio" in a `Theme.surface` card, `height: 0` and
  `visible: false` unless expanded and empty. Force-show probe grim-confirmed the look, then reverted
  (no live empty state was available while Zen/VLC held streams).
- **P18 — Device-name edit no longer shifts alignment. LOW, BY REQUEST (verified).**
  `components/EditableLabel.qml:63` (`AlignVCenter` on the display text) and `:95` (`AlignVCenter` on the input) keep
  the baseline centred in both modes. Grim before/editing crops compared.
- **P19 — Name edit border stands 6 px off the text on both sides and the text never moves. LOW, BY
  REQUEST (verified).** The outline fills the label with `-6 * scale` horizontal margins
  (`components/EditableLabel.qml:66-84`); display `Text` and `TextInput` stay `anchors.fill` with no
  margins, so only the border grows. The row's `clip` would slice the overhang, so entry content
  sits in a wider `clipBox` with compensating margins (`panels/AudioDeviceCard.qml:82-95`) and the
  text lands on identical pixels. Masks on the current build: bright-text bbox `62x14+79+21` idle
  and editing (pixel-identical); left gap ~9 px (≈ 8 px spec at scale 1.25).
- **P20 — Any inside-panel click outside the input cancels the name draft; the panel stays open.
  LOW, BY REQUEST (verified).** One overlay in `PanelBase` covers the card while `cancelItem` is set
  (`panels/PanelBase.qml:233-249`); presses inside the input hole are released (`accepted = false`,
  `:239-241`) so `TextInput` receives them — caret moves, and nothing falls through to the backdrop
  closer (that fall-through previously closed the whole menu on input clicks). All other presses
  call `cancelRequested()` (`:70-95`). Cursor is I-beam over the hole, arrow elsewhere (`:238`).
  Per-card/section overlays and the `nameEditing` flags are gone. Verified with zero injected input:
  `test dispatch` outside → `cancelled`, draft discarded, name blue + panel intact; inside →
  `passthrough`, `caret` 9 → 1, still editing (user also confirmed no-close manually).
- **P21 — Cards show for pinned or active streams; collapse filters rows, not apps. LOW, BY REQUEST
  (verified).** The card gate is `(sectionVisible || hasPinned || hasActive) && hasContent`
  (`panels/AppGroupCard.qml:181-182`), where `hasActive` reads the snapshot's `activeCount` (`:148`)
  and `hasContent` needs at least one stream (`:140`). Collapsed rows gate on
  `expanded || streamPinned || active` (`:150-154`), so an active stream renders inline while an
  inactive unpinned one waits for the per-app chevron. Consequences: with "Application Volumes"
  collapsed an unpinned app with an active stream still appears (Blanket, 3 rows); a pinned app whose
  streams are all inactive keeps its header with no rows; a pinned app with zero streams is hidden
  entirely. Master expand treats every override-less app as expanded
  (`panels/VolumePanel.qml:254`), so it reveals all rows, inactive ones included. Grim-verified on
  eDP-1: Blanket unpinned+active inline; a paused `mpv --ao=pulse` (so `pulse.corked=true`, P3)
  hidden while unpinned, header-only once pinned, gone once its stream was killed while pinned.
- **P22 — App icons render plain, no circle backdrop. LOW, BY REQUEST (verified).** The card header
  uses a bare 22×scale `Image` from `Quickshell.iconPath` (`panels/AppGroupCard.qml:80-86`) instead of
  the old `surfaceHigh` circle, matching the taskbar. Grim-verified: Zen's square icon no longer
  shows a black box.
- **P24 — Volume rename is drivable with zero injected input: `services/TestDriver.qml`. LOW,
  TOOLING (verified).** Panels self-register on open (`panels/PanelBase.qml:105-110`); `shell.qml`
  exposes a `test` IPC target (`enabled`, `setActive`, `openVolume` defaulting to `eDP-1`, `deviceNames`, `editorRect`,
  `beginName`, `setDraft`, `dispatch`, `commit`, `cancelEdit`, `caret`, `nodeName`, `clearAlias`),
  every function a no-op unless armed. Coordinates are screen-local (panel windows are fullscreen).
  Verified flows: begin→draft→outside-`dispatch`→`cancelled`→reverted+open; inside-`dispatch`→
  `passthrough`+caret moves; draft→`commit` persists to the real `audio-aliases.json` and back.
  Notes: `active` resets to false on every reload, so re-arm after reloading; a `FileView` flag
  file was tried first and dropped (stale reads — content frozen at first load); `commit` writes
  the REAL alias file, so snapshot it first and restore by re-committing the original text
  (`clearAlias` deletes the key, which destroys a pre-existing user alias).
- **P25 — Test IPC covers any menu, named volume actions, and self-taking screenshots. LOW,
  TOOLING (verified).** `openPanel(name, [screen])` (default eDP-1), `panelState`,
  `toggleSection`/`toggleApp`/`pinDevice`/`defaultDevice` (the same handlers the buttons call;
  mute/route deliberately have no seams — audible side effects), `priorityOrder`/`priorityMove`
  (read/reorder the P26 device priority; the move seam re-applies enforcement like a real drag),
  `panelRect`/`barRect`
  (screen-absolute via `Hyprland.monitorFor`), `shotPanel`/`shotBar` + `shotPoll` (one `Process`,
  no blind sleep). Verified: control-center opened via IPC and shot at 536x741 byte-identical to
  its rect with full CC content; bar shot exactly 1920x74; volume shot 511x839 exact with full
  menu content; Zen collapse 839→584 then restored; pin round-trip left the pins file
  byte-identical; no-op default flip kept Speaker; section chevron verified flipped via crop.
  Gotchas fixed along the way: `monitorFor` needs a Screen object (a name string throws
  TypeError), `StdioCollector.text` is a property not a function, `grim -g` takes `X,Y WxH`,
  and the daemon's PATH lacks `grim`, so the absolute profile path is used.

- **P26 — Output/input device priority with drag reorder and auto-default. MEDIUM, BY REQUEST
  (verified).** Ordered `node.name` lists per direction (`services/Priority.qml:11-12`, persisted to
  `audio-priority.json`, S5); first run seeds the current default at the top
  (`services/Audio.qml:130-131`). Expanded Output/Input rows render in priority order with a
  `grip-vertical` handle always visible (`panels/AudioDeviceCard.qml:242-270`,
  `theme/Icons.qml:76`); dragging a grip reorders and persists
  (`panels/AudioDeviceCard.qml:133-157`, `panels/VolumePanel.qml:151-154`). Collapsed sections still
  show only current + pinned. An absent device is kept only while it is pinned: `refreshPriority`
  prunes every unpinned name that is not currently connected (`services/Priority.qml:68-77`,
  `services/Audio.qml:132-135`), gated on `Pipewire.ready` so an unenumerated node list cannot wipe
  the file (`services/Audio.qml:189-191`). Pinned absent devices stay ranked and render as dimmed
  name-only rows with no slider or buttons; unpinned ones vanish from both the menu and
  `audio-priority.json` as soon as they disconnect. `Audio` re-asserts the highest-ranked *present*
  device via `preferredDefaultAudioSink/Source` on startup and whenever the connected set changes
  (`services/Audio.qml:113-146,189-207`); a manual default pick holds until such a change, and a
  never-seen device is appended last so it never steals the default. Verified on eDP-1:
  `test priorityOrder`/`priorityMove` round-trips, `wpctl inspect` confirming sink/source flips both
  ways and restore, a `module-null-sink` probe (appended last, default untouched on add, then dragged
  to top and destroyed — unpinned entry gone from menu and file, pinned entry kept and still dimmed),
  staged `stale_ghost_*` names purged on reload, a real `dotool` pointer drag moving Speaker below
  Redmi with the default unchanged, and `grim` of the ordered list including a dimmed pinned ghost
  row.
- **P27 — A null or mixed-type ListModel role silently breaks every delegate. LOW, QUIRK (fixed).**
  Storing `node: null` for absent-device rows under a `required property var node` delegate produced
  zero ListView children (blank cards, model count correct) — then, with the requirement dropped,
  mixing an object and a `""` in the same role coerced the whole role to string and every volume
  read 0. Fix: the model carries only scalar roles and the delegate derives the node via
  `root.nodeFor(entry.key)` (`panels/AudioDeviceCard.qml:117-120,199-210`). Never put QObjects (or
  nulls) in ListModel roles alongside other types.

- **P28 — Pinned app reorder by drag shares one state machine with devices. MEDIUM, BY REQUEST
  (verified).** `components/DragReorder.qml` extracts the gesture from `AudioDeviceCard` (begin/
  update/finish, `movedTop`, `previewOffset`, the `dropShift` behavior and settle timer). Each panel
  owns one, parameterised by `listView`/`model`/`keyRole`/`rowObjectName` plus optional
  `minTarget`/`maxTarget`, and emits `moved(key, target)`. App order now comes from
  `Pins.apps`: `captureApps` sorts pinned groups by `Pins.apps.indexOf` before the count heuristics
  (`panels/VolumePanel.qml:460-475`), so a new pin (`push`, `services/Pins.qml:38-45`) lands last,
  and `Pins.reorderApp` splices + saves. Unpinned apps keep the dynamic sort and have no grip; the
  grip is visible only for a pinned app while the section is expanded. **Gotcha:** the drag translate
  must not sit on the ListView delegate, or `rowIndexAt`'s `mapToItem` measures the dragged card's
  own shifted position and the drop index can never change — devices dodge this with an inner
  transform item, apps now wrap the card in a delegate `Item` (`objectName: "appCard"`, `dragKey`,
  `card`) and translate the inner `AppGroupCard`; `appCards()` resolves that inner card. Verified: a
  real `dotool` grip drag moved Blanket below Zen and `audio-pins.json` followed; a device grip drag
  moved Speaker above HDMI1 with the top/default unchanged; both orders restored; new `test
  appOrder`/`appMove` seams. **Spacing:** the preview/settle offsets must include the list's
  `spacing` — the device list uses `spacing: 0` and hid the omission, but `appList` uses
  `Theme.gap`, so `previewOffset`/`movedTop` now add `listView.spacing` (`components/DragReorder.qml:99-113,149-157`);
  without it a reordered card landed flush against its neighbour instead of leaving the gap. **Mute:**
  the dragged card fades to `0.5` via `layer.enabled` plus root opacity
  (`panels/AppGroupCard.qml:194-195`). Item opacity is inherited per child, so a plain 0.5-opacity
  card let the live `waveCanvas` show through the knob (the wave sits under the knob's left half);
  the layer composites the card's children first (knob over wave) and only then fades the whole
  result, so the card is semitransparent yet the wave never bleeds through the knob. A `Theme.base`
  overlay also hides the wave but keeps the card opaque — rejected, the ask was a see-through card.
  `layer.enabled` clips to the item rect (M3), harmless here since the card already clips and
  nothing overhangs; the layer is only on while the drag/settle is active. The same `layer.enabled`
  fix is on the dragged device row (`panels/AudioDeviceCard.qml:200`), whose content was already
  faded to 0.5 — a device row sits on the shared section card, so it stays a content-only fade
  rather than a see-through card.

## 6. Services / data

- **S1 — Durable state lives in files. MEDIUM, BY DESIGN.** `PersistentProperties` only survives
  reloads, not restarts, so pins and aliases are stored in
  `~/.local/state/quickshell/audio-pins.json` and `audio-aliases.json` (written through
  `bash -lc printf` in `services/Pins.qml`, `services/Aliases.qml`). Aliases are display-only and
  never touch PipeWire, so no other app sees a rename.
- **S2 — `PwNode.properties` needs `PwObjectTracker`. LOW, QUIRK.** The values are invalid unless the
  node is bound; `panels/VolumePanel.qml` tracks every audio node.
- **S3 — `Quickshell.iconPath` depends on the process icon theme. LOW, QUIRK.** It comes from
  `QT_QPA_SYSTEM_ICON_THEME=Papirus-Dark` in `~/.config/hypr/hyprland/execs.lua`; launched without
  it, every app icon degrades to a fallback.
- **S4 — `components/BarSurface.qml` is now the menu card shape too. LOW, MAINTAINANCE.** The name is
  bar-specific; renaming was not requested.
- **S5 — Priority lists persist like pins/aliases, with a debounced write. LOW, BY DESIGN (fixed
  during build).** `services/Priority.qml:58-75` coalesces rapid `save()` calls (one per newly seen
  device) through a 150 ms timer into a single `audio-priority.json` write — without it, concurrent
  `printf` writers interleaved and the file came back as concatenated JSON fragments. Same
  `bash -lc` write pattern as `Pins`/`Aliases` (S1).

## 7. Pre-existing / not ours (untouched)

- **D5 — Tray entry renders a checkerboard. NOT OURS.** The OpenChamber SNI pixmap is broken app-side;
  its `IconName` update failures also spam the log every few seconds.
- **D6 — MPRIS demarshal warnings. NOT OURS.** Blanket publishes `Position` in a type the DBus
  property watcher rejects (`Error demarshalling property update ... Position`).

## 8. Environment / blocked

- **E1 — hyprlock cannot authenticate. HIGH, BLOCKED (needs your action).** `/etc/pam.d/hyprlock` does
  not exist, so PAM falls back to `/etc/pam.d/su`, whose `auth required pam_wheel.so use_uid` fails
  because this user is not in `wheel`. On NixOS: add `security.pam.services.hyprlock = {};` and
  `nixos-rebuild switch`.
- **E2 — Repo has no commits. LOW.** This directory is a git repo on `main` with zero commits, 61
  files staged (6 with further worktree modifications) and only `services/TestDriver.qml`
  untracked. Commits are never made from here (hard rule).

---

## Appendix — how each claim was verified

| Claim | Method |
| --- | --- |
| Menu/bar/popup layout, sorting, filters, aliases | `grim` region captures + `magick` crops and zooms |
| Row reveal animation, panel slide | Temporarily stretched duration (6 s / 1.5 s) plus a frame burst |
| Concave corners, shadow | Temporarily bright card fill (`Theme.red`), temporarily raised shadow opacity (0.25) |
| Scrollability | Temporarily bound `contentY` (content 1001 px in a 938 px viewport) |
| Per-app expansion | Temporarily set `appOverrides` for one app |
| Alias storage | Wrote `audio-aliases.json` by hand, confirmed display and propagation |
| Pin filtering | Wrote a pin for a paused Blanket stream, confirmed it alone reappeared |
| PolkitPrompt chrome (M12) | Temporarily forced `externalRequested: true`, `grim`, reverted |
| All-around shadow (M14) | Throwaway `MultiEffect` config comparing `layer.effect` (clipped) with hidden-source (clean), then `grim` of the bar and a floating menu |
| Floating menus (M15) | `grim` of Session and Window switcher on eDP-1 with the bar forced visible earlier and hidden while open |
| Interaction verification (M13, wheel, keys) | Real input via `dotool` (fractional `mouseto`, 0.0-1.0 of the whole desktop) and `wtype`, confirmed with `grim`/state-JSON diffs |
| Card input mask + focus-change close (M7, M16) | `dotool` fractional `mouseto` + `click`/`wheel` on eDP-1; `hyprctl activewindow` and `test panelState` before/after; `grim` region RMSE (`compare -metric RMSE`) against a no-input baseline |
| Route dropdown position (P14) | Temporary `console.log` probes of `mapToItem` plus `grim` |
| Edit border spacing / text-shift (P19) | `grim` + bright-pixel bbox compare idle vs editing (`62x14+79+21` both), gap read from crop profile (~9 px vs 8 px spec) |
| Outside-cancel / input-click / caret (P20) | `test` IPC (`beginName`/`setDraft`/`dispatch`/`volumeState`) + `grim`; `dispatch` returns `idle`/`cancelled`/`passthrough`. No `dotool`/`wtype` |
| Rename commit incl. alias persistence (P24) | `setDraft` → `commit` → alias file gained the key → re-commit original → key gone and description back, all `grim`-confirmed |
| Self-taking screenshots (P25) | `test shotPanel`/`shotBar` + `shotPoll`; file dims byte-identical to `panelRect` (CC 536x741, bar 1920x74, volume 511x839), contents read directly |
| Named volume actions (P25) | `toggleSection` (chevron flip via crop), `toggleApp Zen` (839→584→839 via shot dims), `pinDevice` round-trip (pins file diff clean), no-op `defaultDevice` |
| Device priority (P26) | `test priorityOrder`/`priorityMove` + `wpctl inspect @DEFAULT_SINK@`/`@DEFAULT_SOURCE@` for flips both ways and restore; `pactl load-module module-null-sink` probe for set-change append (last, default untouched, then dragged to top and destroyed: unpinned entry pruned from menu and file, pinned entry kept dimmed); real `dotool` drag reorder; `grim` of ordered list and dimmed pinned ghost row |
| Master/per-app collapse (P7, P21) | `test setSectionExpanded`/`setAppExpanded` + `appRows` state, plus `grim` crops; active vs inactive staged with a paused `mpv --ao=pulse` (corks the stream) and a throwaway app pin, all reverted |
| Pinned app reorder (P28) | Real `dotool` grip drag (fraction `0.4695, 0.237→0.170` on eDP-1) moved a pinned app below the next one and a device below its neighbour (top kept, default unchanged); `test appOrder`/`appNames`/`priorityOrder` before/after; `audio-pins.json` byte-identical to backup once restored; dragged-card mute confirmed by a 4× `magick` crop of the knob: card is see-through and the wave ends at the knob edge with no bleed |

## Appendix — reusable test recipes

- Open a menu on a chosen monitor: pin focus with
  `hyprctl dispatch 'hl.dsp.focus({ monitor = "eDP-1" })'` (Hyprland here uses Lua dispatchers;
  `movecursor` does not change the focused monitor), then `quickshell ipc call shell volumePanel`,
  and confirm with `hyprctl monitors -j`.
- Toggle exactly once: `quickshell ipc call shell close` then `volumePanel`; two calls in a row cancel.
- Inject input (tools installed): start `ydotoold` once for `ydotool`, or pipe to `dotool` directly
  (`/dev/uinput` is writable via an ACL). Use `wtype "text"` for typing and `wtype -k <Key>` for named
  keys. **Relative `mousemove` is mangled by pointer acceleration** — position absolutely with
  `mouseto`, as a fraction of the whole desktop (sum of monitor widths/heights); `mouseto 0.25 0.5`
  lands on eDP-1's centre in this 2×1920 layout. Confirm the focused monitor with `hyprctl monitors -j`.
  Synthetic clicks do NOT grant Hyprland keyboard focus to `OnDemand` layer surfaces (Qt active-focus
  ≠ Wayland focus), so injected typing lands in the focused window instead of a panel `TextInput`.
- Drive the volume rename without moving the cursor (P24, no user interruption): after every reload
  `quickshell ipc call test setActive true`; `test openVolume [screen]` (defaults to `eDP-1`, pass
  `HDMI-A-1` only when the task needs that screen — never switch the target monitor otherwise);
  `test deviceNames` → `test editorRect "<name>"` gives screen-local coords for crops and
  `dispatch`; `beginName`/`setDraft`/`dispatch x y`/`commit`/`cancelEdit`, reading back
  `volumeState`. Back up `~/.local/state/quickshell/audio-aliases.json` before any `commit`
  test and restore by re-committing the original text (file copies do not refresh Aliases'
  in-memory state; `clearAlias` deletes the key, destroying a pre-existing user alias).
- Stage an inactive app stream without touching the user's audio: `mpv --ao=pulse --pause
  --loop-file=inf --volume=0 <file>` corks the stream (`pulse.corked=true`, P3), so an unpinned app
  with only that stream stays hidden while the section is collapsed; kill the process to remove it.
  Plain `--ao=pipewire` does NOT cork (native clients omit `pulse.corked`), and a fake
  `null-audio-sink` node created as a graph driver disrupts live node bindings — avoid both.
- Toplevel focus needs the `0x` prefix: `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x<hex>" })'`
  (Quickshell's `address` is hex without it).
- Panel windows live on the focused screen only; `hyprctl layers -j` lists the mapped quickshell
  surfaces (`w=1920 h=1080` is a menu, `h=70` is the bar) if a capture looks empty.
- Watch the live log: `quickshell log | grep -E 'WARN|Error|Failed'`, ignoring the DBus
  `StatusNotifier`/`Get` spam (pre-existing, not ours).
- Probe: add a `Timer`/`console.log` behind a `testFired` guard, drive the state, screenshot, revert.
- Always revert probes and restore `~/.local/state/quickshell/*.json` from a backup afterwards.
- Priority reorder without touching audio (P26): `test priorityOrder output` → `test priorityMove
  output "<node.name>" <index>` → re-check order and `test currentDevice`; back up
  `audio-priority.json` first (file copies are fine here — Priority re-reads it on reload, unlike
  Aliases). Absent-device rows: append a fake name and reload — it is pruned once `Pipewire.ready`;
  to stage a surviving dimmed row, pin the name in `audio-pins.json` too.
- Pointer drag with a held button (P26): one piped `dotool` invocation holding the whole gesture
  (`mouseto …; buttondown left; …; buttonup left | dotool`) — separate invocations release the
  button because each instance destroys its virtual device on exit, and `mousedown`/`mouseup` are
  not dotool commands (use `buttondown`/`buttonup`). Verified pattern for a ~60 px downward drag
  on eDP-1 in this 2×1920 layout.
