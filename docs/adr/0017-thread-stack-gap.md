# Notification menu entries are Thread stacks, split by a sixty-minute silence

## Status

accepted

## Context

The notifications panel drew one card per notification, so a chatty thread
(a group chat, a build bot) buried every other app under its own messages.
The Banner already groups, but by *time window* — every toastable active
notification — which is a different concept: it is the live moment, not a
per-thread history.

## Decision

Panel entries are **Thread stacks** (`GLOSSARY.md`): one card per
`appName` + `summary`, holding live notifications and History entries alike,
newest member first. A member joins its thread's stack while its gap to the
previous member is under sixty minutes; a silence of sixty minutes or more
opens a new stack. Seeing the thread's own history when the panel opens
matters more than a uniform card height.

The rule is a silence threshold, not a span limit. There is no cap on how
long a stack may run and no day boundary: a thread messaging every ten
minutes forms one card for hours, and a card may straddle midnight — the
first block belonging to an earlier day than the card's header carries a day
label (`Yesterday · 23:40`). Critical and transient notifications never
stack, so a Critical always stands alone.

Grouping is monotonic: members only ever join, never get evicted, because
the newest arrival is by definition zero minutes from itself. One `×` clears
the whole stack (dismiss the live members, soft-delete the archived ones).
A single-member thread is an ordinary card: one block and no count chip.
Expiry moves a member into History without removing its block; only `×` or
the sending app closing a notification takes a member out.

`services/NotifStacks.qml` owns the rule as a pure function over entries
(reading `key`, `appName`, `summary`, `ts`, `urgency`, `transient`, `active`,
`sortId` and `day` from each, never the clock);
`test notifStacks` feeds it synthetic timestamps so the gap, chaining and
day-crossing cases are checkable without waiting an hour or writing the
archive.

## Considered options

- **Fixed clock buckets** (12:00–12:59): stable, but 12:59 and 13:01 land
  in different cards despite being two minutes apart.
- **Trailing window** (members within sixty minutes of the newest): same
  span guarantee, but an arrival evicts older members, so a card visibly
  splits in two after a gap — and every split needs re-grouping of the
  remainder.
- **Span cap** (a stack may not exceed one hour): splits exactly the busy
  threads stacking exists to compress.
- **Day-scoped stacks**: makes a thread you use daily into one card per day
  and gives up the "everything since the last silence" reading.
- **Thread identity from the resolved desktop entry**: `appIcon` is often
  empty and falls back to a shared `dialog-information`, so icon equality
  merges unrelated apps.

## Consequences

Stack keys are the thread key plus its oldest member's timestamp, so they
survive growth and stay usable for the row-height cache and the scroll
anchor. Loading an older History page can extend an existing archived stack
backwards, which moves that timestamp — and therefore the key — again on
each page. A stack's card can be far taller than the old single-notification
card, which the panel's five-card height budget only approximates.
