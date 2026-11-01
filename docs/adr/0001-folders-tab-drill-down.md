# Folders tab: drill-down browser instead of tree + browse

## Status

accepted

## Context

The music panel's Folders tab showed the library two ways at once: an
expand-in-place folder tree (rows of directories, chevrons, persisted expand
state) and a separate "browse" list (subfolders + track rows) reached from a
per-row list button, with a split animation bridging the two. The tree only
ever showed directories, so anything track-related lived behind the second
view, and the animation existed purely to smooth over the seam between them.

## Decision

One drill-down view. Clicking a folder enters it in place; a clickable
breadcrumb (and a back button) navigates up; the Pinned and Favorites
collections sit at the root next to the top-level folders and are entered the
same way. The tree, the separate browse view, the split animation, and the
`expandedFolders` persistence are removed; the visited path is deliberately
not persisted across restarts (the panel always opens at the root).

Search on this tab is a subtree filter: it matches tracks (title, artist,
album, filename) under the folder you are in, not the whole library, and its
result set is playable from the header. This is a deliberate scope choice —
library-wide search is not offered here.

## Considered options

- Expandable tree + browse view (previous model): rejected — two mental models
  for the same data, and the tree could not show tracks at all.
- Library-wide search results: rejected for this tab — search is scoped to the
  current folder's subtree on purpose; the launcher remains the place for
  global lookups.
- Persisting the last visited path like `lastTab`: rejected — the tab should
  always open at the root.

## Consequences

`music/state.json` no longer stores `expandedFolders` (stale keys are ignored
on load). The retired tree/browse/split machinery (split animation state,
`openBrowse`/`closeBrowse`, per-row list buttons) must not be reintroduced;
navigation affordances are the row click, the back button, and the breadcrumb.
