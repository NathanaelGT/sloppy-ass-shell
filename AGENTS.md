# AGENTS.md

Hand-written Quickshell 0.3.2 config replacing a Noctalia 5.2.1 setup. NixOS, Hyprland,
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
  Wifi flows: `test wifiState` (pending/show/confirm/sections/networks, no cursor or focus
  effects); `wifiBeginPass <name>`/`wifiSetPass`/`wifiPassEcho`/`wifiShowToggle`/`wifiPassRect`
  drive the inline password without typing; `wifiSectionToggle`/`wifiSectionSet` mirror the
  chevrons; `wifiForgetAsk`/`wifiForgetCancel` stage and drop the confirm strip. Live ammo:
  `wifiPassSubmit` attempts a real join, `wifiForgetConfirm` really forgets (reconnect by hand
  afterwards) — announce first, like `routeStream`.
  Battery process list: `test procRows` dumps the rows (kind/key/name/count); `test procMenu <row>`
  opens the right-click context menu for a row, `test procMenuState` reads it back,
  `test procMenuInvoke <index>` clicks an entry (dangerous ones arm first and return `armed`,
  the second invoke executes — kills are real), `test procMenuClose` drops it.
  Music flows: `test musicState` dumps player+queue state; `test musicTab <0|1>` switches
  tabs; `test musicCmd <toggle|play|pause|next|prev|...>` drives transport. Folder tab
  (drill-down): `test folderState` (path, search, pending, breadcrumb, meta, typed rows) is
  the deterministic read; `test folderNavigate <path|pinned|favorites|back>` enters/leaves;
  `test folderSearch <query>` runs the subtree search immediately (poll `folderState` until
  `pending:false`); `test folderRowRect <index>` aims at a row. None of these move the
  cursor or touch playback — row play and double-click have no driver seam and are audible.
  Power menu: NO testing, NO driver seams. Do not test any power menu functionality and do not
  add test ipc for it — rows 2-4 are lock&suspend/reboot/shutdown and a completed hold executes
  for real. The user tests the power menu manually. Lock fires instantly on click, F1, or Return
  when focused.
  Dashboard flows: `test dashState` dumps players (identity/playing), the manual pick (-1 =
  auto), and the shown target with its playing flag and ticking local position;
  `test dashPick <index>` sets the
  manual pick (false when out of bounds); reopening resets the pick.
  `test dashPlayerOpen` opens the MPRIS player dropdown, `test dashMonth <±1>` steps the calendar
  month (returns the new month; slides are not capturable — the calendar slides its day
  numbers and week numbers vertically, the "wk" label and day names stay put). The
  player dropdown selection and MPRIS transport/seek have no driver seam — seeks
  change real state.
  Bar clock: `test clockAltTime <true|false>` sets the alt-time display directly — the same flag
  the pill's right-click toggles (system zone with its own abbreviation vs WITA: +1 hour,
  labelled `WITA`). Verify with `test shotBar`; the flag is global across screens and resets
  on reload or restart.
  Notification flows: `test notifState` dumps dnd/idle/locked, tracked notifications (urgency,
  sticky, ticking remaining ms, hoverPause) and store state (unread, lastSeen, loaded history
  count, exhausted); `test bannerState` dumps the banner (present, app/summary/body/urgency/
  actions, hasImage, ticking banner remaining ms, suppressed) — the eDP-1 clock/bell pill
  morph is driven by the same arrival. Senders drive the live paths: `notify-send -u critical`
  (sticky, red border), `-h string:sound-name:bell` (chime override), transient/resident via
  `notify-send -h` hints. `quickshell ipc call shell setIdle <bool>` / `setLocked <bool>`
  drive the countdown gate and the lock suppression (the real sources are the user's hypridle
  listeners). `test bannerShot` captures the morphed pill (poll `shotPoll`);
  `test bannerDismiss` mirrors the banner right-click (dismiss early — real,
  announces first), `bannerDismissAll` mirrors middle-click.
  `test notifQuery <sql>` / `test notifRaw` run read-only sqlite against
  `~/.local/state/quickshell/notifications.db` and poll the result — use for retention,
  soft-delete and lastSeen assertions, never for writes (the mirror would desync).
  History row delete and panel action buttons have no driver seam
  (clicks are real); the countdown only advances while not idle, so idle pause is asserted
  via `remaining` freezing in `notifState`/`bannerState`, not wall-clock.
  Lock flows: `test lockPreview <true|false>` opens/closes the eDP-1 preview
  (no arg toggles); `test lockAttempt <password>` submits through the REAL PAM
  stack — wrong passwords are safe and expected in tests, the correct password
  closes the preview or unlocks for real; `test lockState` dumps preview/
  locked/secure/attempts/error/capsLock/authenticating/passwordLength —
  never the password itself; capture with `test shotPanel lock
  eDP-1`. While the session is locked, `shell reload` and `test reloadNow` are
  REFUSED; a watched-file live reload cannot be refused and fail-opens the
  session, so never leave watch reloads enabled around a lock test. hyprlock
  remains installed as a manual fallback (its config is untouched) and the
  dormant hypridle configs invoke `quickshell ipc call shell lock`. The lock
  mechanism is docs/adr/0008: a fullscreen overlay-layer `LockWindow` per
  screen (NO ext-session-lock), live compositor blur behind it, blur strength
  overridden while locked and animated down on unlock, `secure` shell-owned.
  Locking engages IMMEDIATELY on the trigger (~90 ms after SUPER+L via
  `~/.local/state/quickshell/lock-trigger`, FileView watch; the trigger
  protocol in docs/adr/0008 guards against stale content).
  `shell lock` ipc remains for hypridle and manual use.
  The real lock (SUPER+L, power-menu rows) is user-tested manually: SUPER+L →
  wrong password shows ✕ N → correct password unlocks; Lock & Suspend hold
  suspends and the lock is up at resume.
- Capture with the driver, not full `grim`: `test panelRect <name>` / `test barRect` return
  screen-absolute geometry; `test shotPanel` / `test shotBar` write a tight crop to
  `/tmp/opencode/test-shot-N.png` — poll `test shotPoll` until `done:true` (one `Process`, no
  blind sleep). Snapshot `audio-aliases.json` AND `audio-pins.json` before `commit`/`pinDevice`/
  `pinApp` tests; restore aliases by re-committing the original text and pins by toggling back.
  Snapshot default sink (`test currentDevice`) and volumes before audible/routing tests
  (`routeStream`, `defaultDevice`, `wpctl`); restore after.
- Fall back to input injection (`ydotool`, `wtype`, `dotool`; `/dev/uinput` is writable) only for
  interactions the driver does not cover, and only after notifying the user 2 s beforehand
  through quickshell's own notification server (`notify-send`, from libnotify, is the sender
  CLI — the shell's `NotificationServer` is the D-Bus server, dunst is gone):
  `notify-send -a opencode -u normal "opencode" "about to move the cursor"` then
  sleep 2, since the user is active on HDMI-A-1. The toast itself closes the focused panel
  (focus steal, 5 s lifetime), so wait it out and reopen the panel before interacting.
  `test beginWork` / `test endWork` already toast
  session start/end the same way, so a separate done notice is only needed for sessions that
  never armed test mode: `notify-send -a opencode -u low "opencode" "testing done — all yours". Run `ydotoold` once for `ydotool`, or pipe commands
  straight to `dotool` — but `mousemove X Y` is RELATIVE (deltas); aim with
  `mouseto X Y` (0.0–1.0 fractions of the whole 3840x1080 layout, e.g.
  `mouseto 0.23724 0.48611` for (911,525)) and verify with `hyprctl cursorpos`.
  `ydotoold`'s virtual device is broken
  here (`unable to find device pointer`), so prefer `dotool`. Re-capture geometry immediately
  before aiming: live lists such as wifi signal resorting invalidate coordinates within seconds
  (a stale aim once disconnected the active network; recovered with
  `nmcli connection up <name>`). Synthetic clicks do NOT grant Hyprland keyboard focus to `OnDemand` layer surfaces, so injected typing lands in the focused window,
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
  a stuck session (stuck watch-off recovers with `endWork`). `reloadNow false` is a SOFT
  reload: it re-reads child files but NOT the root `shell.qml` — after editing shell.qml use
  `test reloadNow true` (hard), and probe liveness (e.g. a version key in an ipc reply) when
  behavior contradicts the files. Edited singletons may also keep running stale code through a
  soft reload (observed: LockState self-locked from the stale trigger-file seq until a hard
  reload applied the guard fix) — after editing `services/*`, prefer `reloadNow true`.
- Toggle once: `quickshell ipc call shell close` then `volumePanel`. Two calls in a row cancel out.
- Cursor shape is invisible to the driver: move the pointer, then `grim -c` with a tight `-g`
  crop. A hover highlight proves delivery, never the cursor. Every `MouseArea` claims
  `Qt.ArrowCursor` by default and Qt uses the topmost claimant, so an overlay `MouseArea` above a
  button leaves the arrow. Name the thief by restarting quickshell with
  `QT_LOGGING_RULES=qt.quick.hover.cursor=true` and reading `setting cursor … from
  QQuickMouseArea(…, z=…)`; relaunch plain afterwards.

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
  Exception: the power menu's destructive rows ignore right-click so the hold-to-confirm cannot be
  bypassed; Lock right-clicks instantly. Exception: the bar clock's right-click does not open the
  dashboard — it toggles the alt-time display (system zone vs WITA).
- All ten menus are built on `panels/PanelBase.qml` (card + Flickable + wheel scroll + slide). Its
  knobs: `attached` (concave vs floating rounded, and hides the bar when a floating one opens),
  `vertical`/`topMargin`, `cardWidth`/`maxCardHeight`, `externalRequested`, `exclusiveFocus`,
  `dismissOnBackdrop`, `autoFocusKeyCatcher`, `cancelItem` (panel-wide edit-cancel overlay with
  an input hole; `VolumePanel` feeds it `activeNameEditor`, `testDispatch(x, y)` emulates a press
  for tests). Scroll the menu with `MouseArea.onWheel`, not a
  `WheelHandler` child (a `MouseArea` consumes the wheel, so the handler never fires).
- `Behavior` animation properties (`duration`, `easing.type`) freeze after the Behavior's first
  trigger in this Quickshell build: `duration: root.merged ? 140 : 450` inside a Behavior runs
  with whichever branch the FIRST trigger evaluated, forever — state-dependent timing silently
  never applies (this is why banner fades "appeared suddenly" for a whole session). Drive
  phase-dependent fades with explicit `NumberAnimation`/`SequentialAnimation` objects restarted
  from the state change (Banner's `splitAnim`/`lobeHideAnim`, Clock's `clockShowAnim`), and keep
  PauseAnimation holds out of Behaviors for the same reason.
- Cursor ownership: Qt takes the cursor from the topmost item that has one, not from the item
  under the pointer, and a bare `MouseArea` has `Qt.ArrowCursor`. So nothing full-surface may sit
  above interactive content — in `panels/PanelBase.qml` the press catcher and the wheel catcher
  stay below `headerArea`/`scroller` (the press catcher was once `z: 20` above them, which made
  every menu button show the arrow while its hover colour still worked). Buttons and clickable
  rows set `cursorShape: Qt.PointingHandCursor`; plain `Item` overlays (`overlayArea`,
  `keyCatcher`, `layer.effect`) claim nothing and are safe.
- Anything that must outlive a restart lives in `~/.local/state/quickshell/*.json`;
  `PersistentProperties` only survives reloads. Exception: notification history is
  `~/.local/state/quickshell/notifications.db`, SQLite driven through the `sqlite3` CLI
  (docs/adr/0004) — the one state file that is not JSON.
- Arrivals display as the Banner (docs/adr/0005), pinned to eDP-1 on purpose: the user works
  on HDMI-A-1 and does not want interruption there — they hear the chime and glance at eDP-1
  if they care. The banner is an overlay pill (`bar/widgets/Banner.qml`) that emerges from
  the bell and covers the clock widget — the underlying widgets keep their geometry, hover
  handlers and the cluster metrics the notifications panel attaches to (the bell's badge,
  DND and dismiss-all stay live throughout; the pill's travel is one `travel` scalar so the
  geometry stays bound to the clock's live, proportional-font width). The bar window is constant-height
  (`Theme.bannerMaxExpand` headroom) and `aboveWindows: true` — layer windows never re-render
  below their initial height, and the old below-toplevels layer hid the expansion behind
  tiled windows (docs/adr/0005). Banner state (latest active
  notification only, 15 s sticky cap, center-panel suppression, panel-open collapse) lives in
  `services/Notifs.qml`; expiry is owned by its 250 ms tick, not the widget: DND and locked
  arrivals still expire into history, and the countdown pauses while idle, hovered, or for
  sticky notifications (Critical, `resident`, `expireTimeout: 0`). The bar badge is the
  unread count (arrivals since the panel last opened), not the live count. The chime plays on
  every arrival not gated by DND/Locked (`pw-play`, sender sound hints first) — even when a
  center panel suppresses the banner. History deletion is a soft delete
  until the 90-day age prune, which runs once at shell startup. The history list is the one
  `ListView` exception to the Column/Flickable preference (virtualization for hundreds of
  rows; keep the Active section a Column).
- PipeWire stream facts: `properties["pulse.corked"]` means paused, `object.serial` is the
  per-instance identity, `application.icon-name` carries a `-symbolic` suffix to strip, and the app
  icon resolves from the toplevel appId/`class` through `services/AppIcons.qml` (desktop entry icon).
- `PwNode.properties` is invalid unless the node is bound with `PwObjectTracker`.
- Reuse before rewriting: `BarSurface`, `Slider`, `EditablePercent`, `EditableLabel`, `MuteButton`,
  `VolumeIcon`, `SectionHeader`, `PlaceholderCard`, `Pins`, `Aliases`, `Audio`.
- Launcher `@provider` entries live in `providers/`, one `pragma Singleton` per provider;
  `services/Providers.qml` is the registry (`providers` list + `providerForKey`) and holds the
  shared param engine. A provider exposes `key`, `name`, `desc`, `logo`, `params`, `errorText` and
  the functions `buildUrl(ctx)`, `requestArgs(url)`, `parse(text)`, `mock(payload)`, `rows(ctx)`,
  `cardTitle(ctx)`, `cardHint(ctx)`; `rows(ctx)` returns row descriptors
  (`key`, `title`, `titleRich`, `titleColor`, `subtitle`, `subtitleRich`, `subtitleColor`, `glyph`,
  `image`, `badge`, `badgeColor`, `action`, `copyText`). Adding a provider is one new file plus one
  registry line — `panels/Launcher.qml` stays provider-agnostic.
- Providers are stateless: the launcher owns the per-provider session (searched term/values,
  results, loading, error) keyed by provider key, because the launcher is instantiated per screen
  and a singleton would leak state between screens.
- A provider with `local: true` resolves offline: the launcher calls its `parse(term)` on every
  keystroke and skips the "press Enter to look up" state, so it exposes no `buildUrl`/`requestArgs`.
- Music Folders tab is a single drill-down browser (docs/adr/0001): click enters a folder or
  collection (Pinned/Favorites live at the root), breadcrumb + back button navigate up; the
  expandable tree, the separate browse view, the split animation and `expandedFolders`
  persistence are retired — do not reintroduce them. The tab opens at the root every session;
  only `lastTab`/`playSource` persist in `music/state.json` (stale `expandedFolders` keys in the
  file are ignored on load).
- Folders-tab search is a subtree filter: MPD `search` with a `(base "path")` filter over the
  folder you are in, matching title/artist/album/filename, tracks only; inside a collection it
  falls back to in-place title/artist matching. While searching, the header button plays the
  result set. The Queue tab keeps the old in-place `matchesSearch` row filter.
- Track rows: single click inert, double-click plays from that track (`playFolderTrack` honors
  the uri), `+` appends, hover heart/pin toggle per-track stickers (`setFavorite`/`setPinned`
  take a uri; the header heart/pin act on the playing song). Collection uris resolve through
  `Mpd.songsByUri` (`listallinfo` cache, invalidated on `database` idle).
- Queue and Folders track cards share one design (docs/adr/0002): 44px card, circular
  accessory buttons, folder card carries the now-playing state keyed on `Mpd.song.file`. The
  two delegates in `panels/MusicPanel.qml` mirror each other's metrics and must be kept in
  sync by hand (no shared component — the queue card's drag/swipe state and test seams cannot
  move into one). The full-card hover MouseArea stays below the trailing buttons, and the
  card's hover state is OR-ed across the row area and every button (`rowHovered`), like the
  queue row's `rowHover`.

## Style

- 2-space indent, no comments, `id: root`, functions before the markup.
- `panels/` screens, `components/` reusable items, `services/` singletons, `providers/` launcher
  providers, `theme/` tokens.
- Prefer `Column`/`Flickable` over `ListView`; Quickshell 0.3.2 models are `ObjectModel` — read `.values`.
- Format as the last step of the task, after the behavior checks: `find . -name '*.qml' | sort >
  /tmp/opencode/qmlformat-files.txt` then the `qmlformat` binary under `/nix/store/*qtdeclarative-6*/bin`
  with `-F /tmp/opencode/qmlformat-files.txt` (in-place, whole tree, idempotent; the root
  `.qmlformat.ini` pins 2-space indent and essential semicolons). It lands after verification, so the
  formatted file is never the version that was behavior-checked and only goes live on the next reload.
- Always brace control-flow bodies (`if`/`else`/`for`/`while`), even when the body is a single statement;
  `else if` chains stay chained. The whole tree is converted already, so this is about new code.
- Report every finding with severity and a `file:line` proof; ask before assuming; keep edits
  surgical; propose extra features instead of adding them; never commit.

## Agent skills

### Issue tracker

Local markdown: issues live as files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Defaults: the five canonical roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.
