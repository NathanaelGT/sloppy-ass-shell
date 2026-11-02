# Notification banner: a grouped clock+bell blob with compact and expanded states

## Status

accepted

## Context

`0005` replaced the toast stack with one Banner: a pill the size of the clock
that traveled left from the bell, covered the clock, expanded downward, and
showed only the latest active notification. That model kept the time hidden for
the whole display, had no way to summarize a second arrival, and used a single
`travel` scalar that could not express compact and expanded states. The three
center pills should stay separate normally and combine only when something
happens, with animation and behavior inspired by Dynamic Island.

## Decision

Music, Clock, and Bell remain three separate pills in the center. A qualifying
arrival merges Clock and Bell into one Banner blob anchored at the bell's left
edge; the blob keeps the pills' combined resting width and grows only downward
while Music stays put. The clock hides while merged, freeing its slot for the
notification, with the full date and zone returning when the pills separate. The
bell remains the leading lobe, wearing the Selected notification's app icon in
place of its glyph while merged and keeping DND (right-click) and dismiss-all
(middle-click).

The Banner has two states. **Compact** is bar-height and shows the latest
notification's app identity (or the group count when more than one is
active), and the latest summary. **Expanded** shows the Selected notification in
full — app, summary, body, image, up to three actions — with up to three compact
rows for the rest of the Notification group; a "+N more" row opens the
notifications panel. N and the list are the live active group, not the Unread
archive. A new arrival takes the Selected slot and extends the Banner session
unless the user has promoted another row or is hovering.

A Banner session runs about five seconds (600 ms compact, then expanded) with an
absolute 15 s cap when any active notification is Critical; group members'
expiry pauses while the Banner is up and resumes on retreat. Critical gets a red
border and row dot. Hover pauses the session. The existing suppression rules
stay: any center or floating panel on eDP-1 suppresses the Banner, side panels
do not; if the group is still active when an unrelated center panel closes, the
Banner replays from compact. Opening the notifications panel by any route
during the session, or using the clock lobe to open the Dashboard, acknowledges
the group and cancels replay.

The retreat is the split, played while the blob is still opaque: the blob is
drawn as two lobes with animated inner corner radii, so the seam pushes apart
past its resting gap and settles back while the lobes round into proper pills
(a staged animation, since the 5 px rest gap alone is too small to read as
motion) while the app icon glides back from the island's left pad to the bell's
center (its X return timed to the header drop, so the path is one diagonal).
Merged, the lobes tile seamlessly into one capsule (the critical red border
lives on a separate overlay that fades with the split, so the tiled joint never
shows a border seam). The clock text fades in from the start of the retreat —
crossfading with the departing summary — while the clock's fill stays
transparent until hidden so the seam's push stays visible; the hidden handover
is an in-place crossfade — app icon to bell glyph — faded in over ~280 ms on
top of lobes that hold opaque until the pill fills are fully in and only then
drop (invisibly — the lobes sit beneath the pills, so the fills never thin
mid-handover; the fills fade from the capsule color at alpha 0, never through
"transparent" black). All banner fade/dock timings are explicit animations
driven from the phase change, not Behaviors.

## Considered options

- Keep the single travel pill: rejected — it cannot represent multiple
  arrivals, and its one scalar cannot morph between compact and expanded
  states.
- Expand only the bell and leave the clock untouched: rejected — the blob
  would not reclaim the clock's slot for the notification.
- Merge all three pills: rejected — Music is an independent activity and would
  have to share a state machine with notifications.
- Summarize Unread History instead of active notifications: rejected — archived
  entries have no live actions and would turn the bar into a second archive.
- Full stacked cards or an accordion list: rejected — it turns the Banner into a
  panel and loses the single-focus glance.
- Manual-only expansion: rejected — arrivals should be readable without a
  click; the compact-then-expand sequence is the requested behavior.

## Consequences

The Banner glossary entry now describes a two-state merged blob; `0005`'s
travel-pill geometry and latest-only display no longer apply. The bar window's
reserved expansion headroom (`Theme.bannerMaxExpand`), its input mask, and the
notification test seams all have to cover the grouped state. Music's existing
title reveal is untouched, but it must never collide with the blob (Music grows
right; the blob keeps the bell's resting left edge and the clock's resting right
edge). The bell badge is hidden while merged because "N new" already carries the
active count; the unread badge returns with the separate bell.

The input mask is the **fixed target rectangle** of the Expanded state, not the
animated blob. A mask Region whose width and height followed the spring made
Quickshell's IPC server answer "Not ready to accept queries yet" after a reload
taken while the Banner was visible; the process restart was the only recovery.
The rectangle is zero while Compact or retreating, and while Expanded it covers
the blob's target bounds, including the rounded corners and the expansion
transient. A static target mask reloads cleanly with the Banner expanded.
