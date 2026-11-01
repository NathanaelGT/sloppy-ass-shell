# Quickshell Bar Config

A hand-written Quickshell desktop shell: status bar, attached menus (panels), and
background services. This glossary covers the domain language of the shell's own
concepts, not general QML/programming vocabulary.

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

## Power

**Power menu**:
The menu of actions that end or pause the session: lock, lock & suspend,
reboot, shutdown.
_Avoid_: session menu, session shell

**Hold-to-confirm**:
The destructive-action gesture: press and hold an action until it fires;
releasing early cancels. Lock is exempt and fires on press.
