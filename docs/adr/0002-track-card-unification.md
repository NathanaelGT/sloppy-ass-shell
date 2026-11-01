# Music menu: one track card design for Queue and Folders

## Status

accepted

## Context

The Queue tab and the Folders tab rendered track rows differently: the queue
card was 38px tall while the folder card was 44px, the drag handle was a small
circle while the folder's add button was a rounded square with a different
hover color, folder cards had no now-playing state, and the folders list laid
its rows flush against each other while queue cards were separated by gaps.
Hovering the folder card's heart/pin/add buttons was also unreliable because
the full-card hover MouseArea sat above them, claiming the arrow cursor for
the whole card and delaying (or swallowing) the buttons' own hover and clicks.

## Decision

The folder track card is the reference; the queue card adopts it. Both cards
share height (44px), radius, colors (`surface` body, `surfaceHigh` on hover or
when playing), typography (track number at 10px, title 10px, artist 9px,
monospace duration 9px), content insets, and accessory chrome: 24px buttons
with circular hover fills in `surfaceHigher`, inset 6px from the card edge.

Exactly two differences remain, both on the trailing edge:

- The rightmost accessory: folders carry an add button, the queue a drag
  handle. Same button, different glyph.
- Folders reveal heart and pin buttons to the left of the duration while the
  card is hovered; the queue reveals nothing extra.

Folder cards additionally adopt the queue's now-playing state: the playing
track (matched by `Mpd.song.file === entry.path`, since folder rows have no
queue id) shows a mauve play icon in place of the number, a bold mauve title,
and the highlighted background.

The folders list uses the same vertical rhythm as the queue: 4px between
cards, applied by the list column's spacing so the root view, the drill-down
view, and search results all inherit it.

Hover mechanics follow the rule that nothing full-surface may sit above
interactive content: the full-card MouseArea sits *below* the trailing
buttons and handles only inert single clicks and double-click-to-play; the
buttons own their hover, cursor, and clicks. Because Qt gives hover to the
topmost MouseArea alone, the card's hover state is an OR over the row area
and every button (`rowHovered`), mirroring the queue row's existing
`rowHover` pattern. The duration text carries extra left padding so the pin
does not crowd it.

## Considered options

- Extracting one shared card component: rejected — the queue card carries
  drag-reorder and swipe-to-delete state (gesture handlers, preview shifts,
  test-driver seams such as `rowCard`) that cannot move into a shared
  component without breaking them; the two implementations mirror each
  other's metrics instead and must be kept in sync by hand.
- Taking the queue card as the reference: rejected — the folder card was the
  design being converged on, and its extra height is what both tabs now use.
- A `HoverHandler` for the card hover state: rejected — the MouseArea OR
  pattern was already proven by the queue row and keeps one idiom per panel.

## Consequences

Queue rows are taller (fewer are visible before scrolling); the drag-reorder
and swipe-reveal geometry derives from row height and scaled automatically.
Clicks on the folder card's add button reach the button itself — previously
the card-level MouseArea consumed them and `+` silently did nothing. The
playing track is now visible while browsing: whichever tab you are on, the
row holding the current song lights up the same way. Any future change to
card metrics must be applied to both implementations (queue delegate and
folder track delegate in `panels/MusicPanel.qml`); there is no shared
component to change once.
