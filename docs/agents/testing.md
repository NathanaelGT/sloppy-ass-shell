# Testing with the driver

Per-panel seam reference. The general rules — screens, announce-first for
audible/destructive actions, reload discipline, snapshot/restore, the
input-injection fallback — live in `AGENTS.md`.

## Capture and geometry

- Capture with the driver, not full `grim`: `test panelRect <name>` /
  `test barRect` return screen-absolute geometry; `test shotPanel` /
  `test shotBar` write a tight crop to `/tmp/opencode/test-shot-N.png` —
  poll `test shotPoll` until `done:true` (one `Process`, no blind sleep).
- Snapshot `audio-aliases.json` AND `audio-pins.json` before
  `commit`/`pinDevice`/`pinApp` tests; restore aliases by re-committing the
  original text and pins by toggling back. Snapshot default sink
  (`test currentDevice`) and volumes before audible/routing tests
  (`routeStream`, `defaultDevice`, `wpctl`); restore after.

## Volume

`test deviceNames` → `test editorRect`,
`beginName`/`setDraft`/`dispatch`/`commit`/`cancelEdit`, reading back
`volumeState` (`dispatch` returns `idle`/`cancelled`/`passthrough`);
`toggleSection`/`toggleApp`/`pinDevice`/`defaultDevice` mirror the
chevron/button handlers (`pinApp` pins a whole app,
`routeStream <app> <index> <target|Default>` routes audibly — announce
first); mute has no seam — audible side effects. `test appRows <app>` dumps
row keys/labels/pins for deterministic assertions without screenshots.

## Wifi

`test wifiState` (pending/show/confirm/sections/networks, no cursor or focus
effects); `wifiBeginPass <name>`/`wifiSetPass`/`wifiPassEcho`/`wifiShowToggle`/
`wifiPassRect` drive the inline password without typing;
`wifiSectionToggle`/`wifiSectionSet` mirror the chevrons;
`wifiForgetAsk`/`wifiForgetCancel` stage and drop the confirm strip. Live
ammo: `wifiPassSubmit` attempts a real join, `wifiForgetConfirm` really
forgets (reconnect by hand afterwards) — announce first.

## Battery process list

`test procRows` dumps the rows (kind/key/name/count); `test procFilter <text>`
sets the process filter through the real input path (idempotent, empty string
clears — read back with `procRows`); `test procMenu <row>` opens the
right-click context menu for a row, `test procMenuState` reads it back,
`test procMenuInvoke <index>` clicks an entry (dangerous ones arm first and
return `armed`, the second invoke executes — kills are real),
`test procMenuClose` drops it.

## Music

`test musicState` dumps player+queue state; `test musicTab <0|1>` switches
tabs; `test musicCmd <toggle|play|pause|next|prev|...>` drives transport.
Folder tab (drill-down): `test folderState` (path, search, pending,
breadcrumb, meta, typed rows) is the deterministic read;
`test folderNavigate <path|pinned|favorites|back>` enters/leaves;
`test folderSearch <query>` runs the subtree search immediately (poll
`folderState` until `pending:false`); `test folderRowRect <index>` aims at a
row. None of these move the cursor or touch playback — row play and
double-click have no driver seam and are audible.

## Dashboard

`test dashState` dumps players (identity/playing), the manual pick
(-1 = auto), and the shown target with its playing flag and ticking local
position; `test dashPick <index>` sets the manual pick (false when out of
bounds); reopening resets the pick. `test dashPlayerOpen` opens the MPRIS
player dropdown, `test dashMonth <±1>` steps the calendar month (returns the
new month; slides are not capturable — the calendar slides its day numbers
and week numbers vertically, the "wk" label and day names stay put). The
player dropdown selection and MPRIS transport/seek have no driver seam —
seeks change real state.

## Bar clock

`test clockAltTime <true|false>` sets the alt-time display directly — the
same flag the pill's right-click toggles (system zone with its own
abbreviation vs WITA: +1 hour, labelled `WITA`). Verify with `test shotBar`;
the flag is global across screens and resets on reload or restart.

## Notifications

`test notifState` dumps dnd/idle/locked, tracked notifications (urgency,
sticky, ticking remaining ms, hoverPause) and store state (unread, lastSeen,
loaded history count, exhausted); `test bannerState` dumps the banner
(present, app/summary/body/urgency/actions, hasImage, ticking banner
remaining ms, suppressed) — the eDP-1 clock/bell pill morph is driven by the
same arrival. Senders drive the live paths through an external D-Bus sender:
`env -u LD_LIBRARY_PATH notify-send -u critical …` (sticky, red border),
`-h string:sound-name:bell` (chime override), transient/resident via
`-h boolean:transient:true` / `-h boolean:resident:true`.
`quickshell ipc call shell setIdle <bool>` / `setLocked <bool>` drive the
countdown gate and the lock suppression — manual overrides of the shell-owned
idle detection (docs/adr/0010); nothing else writes `Notifs.locked`.
`test bannerShot` captures the morphed pill (poll `shotPoll`);
`test bannerDismiss` mirrors the banner right-click (dismiss early — real,
announces first), `bannerDismissAll` mirrors middle-click.
`test notifQuery <sql>` / `test notifRaw` run read-only sqlite against
`~/.local/state/quickshell/notifications.db` and poll the result — use for
retention, soft-delete and lastSeen assertions, never for writes (the mirror
would desync). `test notifScrollState [screen]` dumps the notification list's
scroll state (contentY, contentHeight, viewportHeight, count, maxScroll,
thumbY, thumbHeight, dragIndex, topIndex, firstCardY, lastEnd) — read-only,
the scroll-position seam for thumb/wheel assertions. History row delete and
panel action buttons have no driver seam (clicks are real); the countdown
only advances while not idle, so idle pause is asserted via `remaining`
freezing in `notifState`/`bannerState`, not wall-clock.

## Lock

`test lockPreview <true|false>` opens/closes the eDP-1 preview (no arg
toggles); `test lockAttempt <password>` submits through the REAL PAM stack —
wrong passwords are safe and expected in tests, the correct password closes
the preview or unlocks for real; `test lockState` dumps
preview/locked/secure/attempts/error/capsLock/authenticating/passwordLength —
never the password itself; capture with `test shotPanel lock eDP-1`. Locking
engages IMMEDIATELY on the trigger (~90 ms after SUPER+L via
`~/.local/state/quickshell/lock-trigger`, FileView watch; the trigger
protocol in docs/adr/0008 guards against stale content). The real lock
(SUPER+L, power-menu rows) is user-tested manually.

## Idle chain (docs/adr/0010)

`test idleState` dumps the loaded config
(loaded/configEnabled/idleSeconds/stages), detection (detected/manual/idle),
dim state (dimmed/preDim/brightness), chain state
(chainRunning/chainApplied/chainElapsed/chainArmed) and the suspend gate
(waiting/audioPlaying/lastAudioAt/silenceSeconds/gateSeconds) — read-only, no
cursor or focus effects. `test idleArm <idleSec> <dimSec> <dpmsSec> <lockSec>`
(all four args required by the ipc; 0 keeps that loaded timeout) arms a
short-timeout IN-MEMORY config (idle.json is never written; pass 0 to keep a
loaded timeout, suspend has no override); `test idleDisarm` restores the
loaded config. Arm is NOT idempotent — a second arm while armed returns
`armed:false`, disarm first. Real effects when the elapsed time is reached:
Dim (every monitor to 0, ddcutil first, brightnessctl last), DPMS off
(global), Lock (the same engage as SUPER+L — the session is LOCKED for real,
reloads are refused and the password is needed) — announce first and snapshot
brightness (`dimmed`/`preDim`/`brightness` in `idleState`); any input reverts
applied stages (DPMS on, pre-dim brightness back). `test idleDimRoundTrip`
does a real dim to 0 with its own announce toast and auto-restores after 4 s
— read `dimmed`/`preDim` back through `idleState` while it runs. Suspend
never fires while armed (gated in the engine, not time-skipped): verify the
gate by state inspection only — play real audio with `test musicCmd play`,
watch `audioPlaying`/`silenceSeconds`/`waiting` in `idleState`; a live
suspend test is user-run. Reload caveats: after editing idle services prefer
`reloadNow true`; a reload or restart while dimmed resets the Brightness
singleton (`dimmed:false` with hardware still at 0, preDim lost) — restore
manually (`brightnessctl set <n>%`, `ddcutil setvcp 10 <n>`) or re-run the
round trip.
