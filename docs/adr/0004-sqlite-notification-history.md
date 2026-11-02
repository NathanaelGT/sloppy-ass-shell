# Notification history is SQLite, not JSON

## Status

accepted

## Context

The notification rework (glossary: History) keeps a persisted archive of past
notifications: 90-day retention, soft delete from the panel, optional image
blobs up to 2 MB, an unread/last-seen marker, and page-wise loading so the
panel never materializes the whole archive. Every other persisted state in
this config is a small JSON file under `~/.local/state/quickshell/`
(`audio-aliases.json`, `music/state.json`, `launcher-favorites.json`, …) read
and written in-process. A notification archive differs in kind: it is
append-heavy, pruned by age, filtered by deletion state, and can carry binary
blobs — and Quickshell 0.3.1 has no SQL binding, so "SQLite" means shelling
out to the `sqlite3` CLI through `Quickshell.Io.Process`.

## Decision

History lives in `~/.local/state/quickshell/notifications.db` (WAL mode),
driven by `sqlite3 -json` subprocess calls from a single FIFO command queue in
`services/NotifStore.qml`. The UI binds to an in-memory mirror the service
owns; every mutation is mirrored synchronously in memory and persisted
asynchronously, so the interface never waits on the database (measured on this
machine: ~1 ms per spawn+query, ~3 ms for a 1000-row page). Image blobs ride
in the database as BLOBs, written by copying the sender's (short-lived) image
file to a temp cache at arrival and inserting it with `readfile()` at close;
they are read out lazily per displayed row with `writefile()` to a temp file.
Startup loads the newest ~200 metadata rows and fetches more on scroll; blobs
are never loaded in bulk.

## Considered options

- JSON file per the existing convention: rejected — whole-file rewrite per
  notification, base64 bloat for blobs, no incremental load, and soft delete /
  age prune become full-file scans.
- SQLite C++ plugin or native QML binding: rejected — none exists in
  Quickshell 0.3.1 and a compiled plugin is out of scope for a hand-written
  config.
- No persistence (today's behavior): rejected — dismissing a notification
  destroyed it; the rework exists to fix that.

## Consequences

`notifications.db` is the one state file that is not JSON and needs the
`sqlite3` CLI installed; it is opaque to hand-editing compared to the JSON
files. Writes are fire-and-forget: a crash can lose the last unflushed
mutation (notifications are ephemeral data; acceptable). The database has a
single writer (this shell) — no locking discipline beyond the serialized
queue. The soft-delete and unread rules live in SQL semantics
(`deleted_at`, a `meta` table for `lastSeen`) and must be kept consistent with
the in-memory mirror, which is authoritative for display.
