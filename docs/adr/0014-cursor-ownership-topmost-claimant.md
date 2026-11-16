# Cursor ownership: the topmost claimant wins

## Status

accepted

## Context

Menu buttons showed the arrow cursor while their hover colour still worked,
and the pointer shape is invisible to the test driver — a hover highlight
proves delivery, never the cursor; verifying a shape needs a `grim -c`
capture with a tight `-g` crop after moving the pointer. Qt assigns the
cursor from the topmost item that claims one, not from the item under the
pointer, and a bare `MouseArea` claims `Qt.ArrowCursor` by default.

## Decision

Nothing full-surface may sit above interactive content. In
`panels/PanelBase.qml` the press catcher and the wheel catcher stay below
`headerArea`/`scroller`. Buttons and clickable rows set
`cursorShape: Qt.PointingHandCursor`; plain `Item` overlays (`overlayArea`,
`keyCatcher`, `layer.effect`) claim nothing and are safe.

To name a cursor thief, restart quickshell with
`QT_LOGGING_RULES=qt.quick.hover.cursor=true` and read the
`setting cursor … from QQuickMouseArea(…, z=…)` log lines; relaunch plain
afterwards.

## Consequences

New full-surface overlays must either claim no cursor or stay below
interactive content — a hover highlight working while the arrow shows is the
symptom of a thief sitting above.
