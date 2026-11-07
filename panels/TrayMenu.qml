import QtQuick
import Quickshell
import "../theme"
import "../services"

PanelBase {
  id: root

  panelName: "tray"
  align: "right"
  cardWidth: Math.round(240 * Theme.scale)
  contentOuterPad: Math.round(6 * Theme.scale)

  readonly property var entries: opener.children ? opener.children.values : []
  property var expandedEntries: []
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
      return false
    }
    root.expandedEntries = root.expandedEntries.concat([entry])
    return true
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
    const index = root.expandedEntries.indexOf(entry)
    const opener = kidsInstantiator.objectAt(index)
    if (!opener || !opener.children) {
      return []
    }
    return opener.children.values
  }

  function rebuildRows() {
    root.rows = root.buildRows()
  }

  function bumpRevision() {
    root.rowsRevision += 1
  }

  function resetMenu() {
    root.expandedEntries = []
    root.rows = []
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
        opener.menu = Panels.trayItem ? Panels.trayItem.menu : null
      } else {
        opener.menu = null
        root.resetMenu()
      }
    }
  }

  QsMenuOpener {
    id: opener
  }

  Instantiator {
    id: kidsInstantiator

    model: root.expandedEntries

    delegate: QsMenuOpener {
      menu: modelData
    }

    onObjectAdded: (index, object) => {
      if (object.children) {
        object.children.valuesChanged.connect(root.bumpRevision)
      }
    }
  }

  Connections {
    target: kidsInstantiator

    function onObjectRemoved(index, object) {
      if (object.children) {
        object.children.valuesChanged.disconnect(root.bumpRevision)
      }
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
          onExpandToggled: entry => root.toggleExpanded(entry)
        }
      }
    }
  }
}
