# Quickshell Bar Config

A hand-written Quickshell desktop shell: status bar, attached menus (panels), and
background services. This glossary covers the domain language of the shell's own
concepts, not general QML/programming vocabulary.

## Bar

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

**Locked**:
hyprlock holding the session. While locked, no Banner is shown;
arrivals go straight to History.

**Chime**:
The arrival sound. Plays on every arrival not muted by DND (Critical
excepted) or Locked — even when the Banner is suppressed by an open
panel. Honors a sender-requested sound, else falls back by urgency.
