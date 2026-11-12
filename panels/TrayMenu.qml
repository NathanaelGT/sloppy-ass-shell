import QtQuick
import Quickshell
import "../theme"
import "../services"

PanelBase {
  id: root

  panelName: "tray"
  align: "right"
  cardWidth: Math.round(240 * Theme.scale)
  contentOuterPad: Math.max(Math.round(6 * Theme.scale), Theme.scrollThumbStrip)
  animateCardHeight: true

  readonly property var entries: opener.children ? opener.children.values : []
  property var expandedEntries: []
  property var kidOpeners: []
  property var loadedItem: null
  property var revealEntry: null
  property var rows: []
  property int rowsRevision: 0

  horizontalOffset: {
    if (Panels.trayAnchorX < 0) {
      return 0
    }
    const pad = Math.round(4 * Theme.scale)
    const base = width - cardWidth - edge
    const desired = Math.round(Panels.trayAnchorX - cardWidth / 2)
    return Math.max(pad - base, Math.min(desired - base, width - cardWidth - pad - base))
  }

  function isExpanded(entry) {
    return root.expandedEntries.indexOf(entry) >= 0
  }

  function toggleExpanded(entry) {
    if (!entry || !entry.hasChildren) {
      return false
    }
    const index = root.expandedEntries.indexOf(entry)
    if (index >= 0) {
      const next = root.expandedEntries.slice()
      next.splice(index, 1)
      root.expandedEntries = next
      root.closeKidOpener(entry)
      return false
    }
    root.openKidOpener(entry)
    root.expandedEntries = root.expandedEntries.concat([entry])
    return true
  }

  function openKidOpener(entry) {
    const opener = kidOpenerComponent.createObject(root, {
      menu: entry
    })
    opener.childrenChanged.connect(() => root.hookKidOpener(opener))
    root.hookKidOpener(opener)
    root.kidOpeners.push(opener)
  }

  function hookKidOpener(opener) {
    if (opener.children) {
      opener.children.valuesChanged.connect(root.bumpRevision)
      root.bumpRevision()
    }
  }

  function closeKidOpener(entry) {
    for (let i = 0; i < root.kidOpeners.length; i++) {
      const opener = root.kidOpeners[i]
      if (opener.forEntry === entry) {
        root.kidOpeners.splice(i, 1)
        opener.destroy()
        return
      }
    }
  }

  function buildRows() {
    const rows = []
    const walk = (list, depth) => {
      for (let i = 0; i < list.length; i++) {
        const entry = list[i]
        const expanded = root.isExpanded(entry)
        rows.push({
          entry: entry,
          depth: depth,
          expanded: expanded
        })
        if (entry.hasChildren && expanded) {
          walk(kidValues(entry), depth + 1)
        }
      }
    }
    walk(root.entries, 0)
    return rows
  }

  function kidValues(entry) {
    for (let i = 0; i < root.kidOpeners.length; i++) {
      const opener = root.kidOpeners[i]
      if (opener.forEntry === entry) {
        return opener.children ? opener.children.values : []
      }
    }
    return []
  }

  function rebuildRows() {
    root.rows = root.buildRows()
  }

  function bumpRevision() {
    root.rowsRevision += 1
  }

  function resetMenu() {
    root.expandedEntries = []
    for (let i = 0; i < root.kidOpeners.length; i++) {
      root.kidOpeners[i].destroy()
    }
    root.kidOpeners = []
    root.rows = []
  }

  function revealExpandedRow(entry) {
    const items = rowItems()
    for (let i = 0; i < items.length; i++) {
      if (items[i].entry === entry) {
        const next = items[i + 1]
        ensureVisibleItem(next || items[i])
        return
      }
    }
  }

  function rowItems() {
    const items = []
    for (let i = 0; i < menuColumn.children.length; i++) {
      const kid = menuColumn.children[i]
      if (kid.invoke) {
        items.push(kid)
      }
    }
    return items
  }

  function testTrayState() {
    const items = rowItems()
    const rows = []
    for (let i = 0; i < items.length; i++) {
      rows.push(items[i].state())
    }
    return {
      open: root.open,
      item: Panels.trayItem ? Panels.trayItem.title : "",
      anchorX: Panels.trayAnchorX,
      rows: rows
    }
  }

  function testTrayRowRect(index) {
    const row = rowItems()[index]
    if (!row) {
      return null
    }
    const point = row.mapToItem(null, 0, 0)
    return {
      x: point.x,
      y: point.y,
      width: row.width,
      height: row.height
    }
  }

  function testTrayInvoke(index) {
    const row = rowItems()[index]
    if (!row) {
      return ""
    }
    return row.invoke()
  }

  function testTrayExpand(index) {
    const row = rowItems()[index]
    if (!row) {
      return false
    }
    return root.toggleExpanded(row.entry)
  }

  onEntriesChanged: root.rebuildRows()
  onExpandedEntriesChanged: root.rebuildRows()
  onRowsRevisionChanged: root.rebuildRows()
  Component.onCompleted: root.rebuildRows()

  Connections {
    target: root

    function onOpenChanged() {
      if (root.open) {
        if (Panels.trayItem !== root.loadedItem) {
          root.resetMenu()
        }
        opener.menu = Panels.trayItem ? Panels.trayItem.menu : null
        root.loadedItem = Panels.trayItem
      }
    }

    function onVisibleChanged() {
      if (!root.visible) {
        opener.menu = null
        root.resetMenu()
      }
    }
  }

  Connections {
    target: Panels

    function onTrayItemChanged() {
      if (!root.open) {
        return
      }
      opener.menu = Panels.trayItem ? Panels.trayItem.menu : null
      root.loadedItem = Panels.trayItem
      root.resetMenu()
    }
  }

  Connections {
    target: opener

    function onMenuChanged() {
      if (root.open && !opener.menu) {
        Panels.close()
        Panels.trayItem = null
      }
    }
  }

  QsMenuOpener {
    id: opener
  }

  Component {
    id: kidOpenerComponent

    QsMenuOpener {
      property var forEntry: menu
    }
  }

  Timer {
    id: revealTimer

    interval: 240
    onTriggered: {
      if (root.revealEntry) {
        root.revealExpandedRow(root.revealEntry)
      }
      root.revealEntry = null
    }
  }

  Item {
    width: parent.width
    implicitHeight: menuColumn.implicitHeight

    Column {
      id: menuColumn

      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Math.round(2 * Theme.scale)

      Repeater {
        model: root.rows

        delegate: TrayMenuEntry {
          interactive: root.open

          onExpandToggled: entry => {
            if (root.toggleExpanded(entry)) {
              root.revealEntry = entry
              Qt.callLater(() => root.revealExpandedRow(entry))
              revealTimer.restart()
            }
          }
        }
      }
    }
  }
}
