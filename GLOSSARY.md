# Quickshell Bar Config

A hand-written Quickshell desktop shell: status bar, attached menus (panels), and
background services. This glossary covers the domain language of the shell's own
concepts, not general QML/programming vocabulary.

## Bar

**Pill**:
One of the bar's three right-side cluster widgets: the bell, the clock, and
the music widget. Pills rest side by side and can temporarily merge.
_Avoid_: widget (for bell/clock/music specifically), button

**Merge**:
Two Pills briefly sharing one blob: the clock is covered or joined by the
Banner on a notification arrival, or by the music widget's revealed title on
a playback event. Every merge happens on exactly one screen; the others stay
at rest.
_Avoid_: combine, morph

**Arrival**:
An event that can trigger a Merge: a notification arriving, or music
playback starting or advancing. Screen-scoped: a user-clicked arrival targets
the screen the click happened on; automatic and external ones target eDP-1.
_Avoid_: trigger, event (unqualified)

**Workspaces**:
The bar widget showing one group per workspace on the widget's screen: the
workspace number and every window icon, hairline-separated inside one
capsule. Clicking a group focuses the workspace, an icon focuses its window,
wheeling over a group cycles its windows, right-click opens the window
switcher. A sliding underline marks the focused window.
_Avoid_: taskbar, workspace bar

**Alt time**:
The bar clock's right-click display mode: WITA — one hour ahead, labelled
`WITA` — instead of the system zone with its own abbreviation. Display-only:
it changes what the clock shows, never the system timezone.

**Auto-hide bar**:
The bar's hidden-until-hover visibility mode: hidden until the cursor nears
the top edge of its screen. HDMI-A-1 runs this mode; contrast the pinned bar.
_Avoid_: hidden bar, collapsed bar

**Pinned bar**:
The bar's always-visible visibility mode with its screen space reserved.
eDP-1 runs this mode; contrast the auto-hide bar.
_Avoid_: fixed bar, static bar

**Tileless workspace**:
A screen's active workspace holding zero tiled windows — completely empty or
floating-only. While a screen's workspace is tileless, its bar stays visible
even in auto-hide mode; re-hides (deferred while the cursor is on the trigger
area) once any tiled window is on it.

**Attached menu**:
A menu rendered fused to the bar's underside, sharing the bar's concave top
corners. Most panels are attached.
_Avoid_: docked menu, bar menu

**Floating menu**:
A menu rendered detached from the bar as a plain rounded card, e.g. the
window switcher. Contrast the attached menu.
_Avoid_: detached menu

**Top-docked**:
The attached menu's fullscreen override: when a fullscreen window covers the
menu's screen, the menu docks flush to the screen's top edge on the overlay
layer instead of under the bar, keeping the concave shape. Under fullscreen
the compositor alpha-hides top-layer surfaces (the bar), so the bar gap would
be blank and attached menus on the top layer would be invisible.
_Avoid_: fullscreen mode, top mode

## Music

**Music panel**:
The menu attached to the bar's music widget, with two tabs.
_Avoid_: music menu (when precision matters)

**Folders tab**:
The music panel's library tab: a single drill-down browser over the library's
folders and collections.
_Avoid_: folder view, browse tab

**Queue tab**:
The music panel's tab showing the current play queue.

**Drill-down**:
The Folders tab's navigation model: one list at a time; opening a folder shows
its contents in place; moving up uses the breadcrumb. Replaces the retired pair
of an in-place expandable tree plus a separate browse list.
_Avoid_: tree view, browse view (both retired)

**Collection**:
A curated track list that is not a folder — Pinned and Favorites. Shown at the
root of the Folders tab alongside top-level folders.

**Source**:
The folder or collection the current queue was built from.

**Track**:
One song file in the MPD library.

**Search**:
The Folders tab's filter: matches tracks (title, artist, album, filename) in the
current folder's whole subtree, not the whole library. Inside a collection it
degrades to in-place title/artist matching. The Queue tab's in-place row filter
is a different thing and has no name of its own.
_Avoid_: library search, global search

**Pinned**:
A collection of tracks marked for heavy rotation and quick access.

**Favorites**:
A collection of tracks marked as loved.

## Dashboard

**Dashboard**:
The menu attached to the bar's clock widget: the now-playing card and the
month calendar. Shows nothing another panel already owns.
_Avoid_: control center (retired name)

**Now-playing card**:
The dashboard's mini-player for MPRIS players: one card for the active player,
navigable between players. Distinct from the Music panel, which drives MPD
only.

## Power

**Power menu**:
The menu of actions that end or pause the session: lock, lock & suspend,
reboot, shutdown.
_Avoid_: session menu, session shell

**Hold-to-confirm**:
The destructive-action gesture: press and hold an action until it fires;
releasing early cancels. Lock is exempt and fires on press.

## Lock

**Locked**:
The shell's session lock: the shell itself holds the lock on every screen,
entered with SUPER+L or the power menu's Lock, exited only by the correct
password at the Lock screen. While locked, no Banner is shown; arrivals go
straight to History. _Avoid_: hyprlock — kept installed only as a manual
fallback, never the shell's lock

**Lock screen**:
The full-screen surface the shell shows while Locked: the desktop as it
looked when the lock was requested, blurred and dimmed, with the clock and
the password field. Typing is accepted only once the compositor confirms
the lock is secure. _Avoid_: login screen, greeter

## Notifications

**Banner**:
The bar's transient notification display: the clock and bell pills merge
into one blob that keeps their combined resting width and shows a
Notification group, then separate again when the display ends. The bell
anchors the blob's left edge and wears the Selected notification's app
icon while merged; the clock hides, freeing its slot for the notification.
eDP-1 only.
_Avoid_: toast (retired top-right stack), notification OSD — OSD is the
volume/brightness pill

**Notification group**:
The active notifications currently eligible for the Banner, newest
first; DND and Locked filter the group. It is the live moment, not the
Unread count or the History archive. _Avoid_: unread list, notification
stack

**Active notification**:
A notification still tracked by the shell, neither dismissed nor
expired. _Avoid_: unread (an archive concept)

**Compact state**:
The Banner's bar-height state: the clock, the latest notification's app
identity or the group count, and the latest summary. It precedes the
Expanded state; the Expanded state collapses back through it when the
display ends. _Avoid_: mini banner, peek

**Expanded state**:
The Banner's state below the bar: the Selected notification in full,
plus the rest of the Notification group as compact rows. _Avoid_: detail
view, banner card

**Selected notification**:
The member of the Notification group shown in full in the Expanded
state; newest by default, promoted by clicking its row. _Avoid_: focused
notification

**OSD**:
The bottom-center pill announcing transient state: volume, brightness,
microphone. Never shows notifications. _Avoid_: calling toasts OSDs

**DND**:
Do Not Disturb: the global notification mute. While on, arriving
notifications skip the Banner but are still archived to History;
Critical notifications ignore it. It resets when the shell restarts.

**Urgency**:
A notification's priority as declared by the sending app: Low, Normal, or
Critical. Critical bypasses DND and never auto-expires.

**History**:
The persisted archive of past notifications; dismiss or expire moves a
notification here. Entries are kept for 90 days; deleting an entry from
the panel only hides it until the age prune. Survives restarts.

**Unread**:
History entries that arrived after the panel was last opened. Drives the
bar badge count and clears when the panel opens.

**Idle**:
Five seconds without keyboard or pointer input. While idle, a banner's
countdown is paused; the first input resumes it. Unrelated to the longer
idle timeouts registered for power management.

**Chime**:
The arrival sound. Plays on every arrival not muted by DND (Critical
excepted) or Locked — even when the Banner is suppressed by an open
panel. Honors a sender-requested sound, else falls back by urgency.
