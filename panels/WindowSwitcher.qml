import QtQuick
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "window-switcher"
  align: "center"
  vertical: "center"
  attached: false
  cardWidth: Math.round(420 * Theme.scale)
  exclusiveFocus: true
  forceKeyboard: root.open

  readonly property var items: {
    const monitor = Hypr.monitorFor(root.modelData)
    if (!monitor) {
      return []
    }
    const info = monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace && monitor.lastIpcObject.specialWorkspace.name ? monitor.lastIpcObject.specialWorkspace : null
    let workspace = null
    if (info) {
      const all = Hypr.workspaces
      for (let i = 0; i < all.length; i++) {
        if (all[i].name === info.name) {
          workspace = all[i]
          break
        }
      }
    }
    if (!workspace) {
      workspace = monitor.activeWorkspace
    }
    if (!workspace || !workspace.toplevels) {
      return []
    }
    const list = workspace.toplevels
    return list.values ? list.values : list
  }

  property int selected: -1

  function displayName(toplevel) {
    if (!toplevel) {
      return "untitled"
    }
    if (toplevel.title) {
      return toplevel.title
    }
    if (toplevel.wayland && toplevel.wayland.appId) {
      return toplevel.wayland.appId
    }
    const ipc = toplevel.lastIpcObject
    if (!ipc) {
      return "untitled"
    }
    return ipc.class || ipc.initialClass || "untitled"
  }

  function seedSelection() {
    const count = root.items.length
    if (count === 0) {
      return
    }
    for (let i = 0; i < count; i++) {
      if (String(root.items[i].address) === String(root.windowAtOpen)) {
        root.selected = i
        return
      }
    }
    root.selected = 0
  }

  function stepSelection(delta) {
    const count = root.items.length
    if (count === 0) {
      return
    }
    if (root.selected < 0) {
      root.seedSelection()
      return
    }
    root.selected = (root.selected + delta + count) % count
    const row = repeater.itemAt(root.selected)
    if (row) {
      root.ensureVisibleItem(row, Math.round(8 * Theme.scale))
    }
  }

  function activate(index) {
    const item = root.items[index]
    if (!item) {
      return
    }
    Panels.close()
    Hypr.focusToplevel(item.address)
  }

  onOpened: root.seedSelection()

  onItemsChanged: if (root.selected >= root.items.length) {
    root.selected = root.items.length - 1
  }

  onKeyPressed: event => {
    const key = event.key >= Qt.Key_Keypad_1 && event.key <= Qt.Key_Keypad_9 ? Qt.Key_1 + (event.key - Qt.Key_Keypad_1) : event.key
    if (key >= Qt.Key_1 && key <= Qt.Key_9) {
      root.activate(key - Qt.Key_1)
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activate(root.selected)
    } else if (event.key === Qt.Key_Down) {
      root.stepSelection(1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      root.stepSelection(-1)
      event.accepted = true
    }
  }

  Connections {
    target: Panels

    function onCycleCountChanged() {
      if (Panels.openOn("window-switcher", root.screenId)) {
        root.stepSelection(1)
      }
    }
  }

  Connections {
    target: root

    function onOpenChanged() {
      if (!root.open) {
        root.selected = -1
      }
    }
  }

  Column {
    id: list

    width: parent.width
    spacing: Math.round(4 * Theme.scale)

    Repeater {
      id: repeater

      model: root.items

      delegate: Rectangle {
        id: entry

        required property var modelData
        required property int index

        width: parent.width
        height: Math.round(38 * Theme.scale)
        radius: Math.round(10 * Theme.scale)
        color: root.selected === entry.index || entryMouse.containsMouse ? Theme.surface : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Math.round(12 * Theme.scale)
          anchors.right: shortcut.left
          anchors.rightMargin: Math.round(8 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          text: root.displayName(entry.modelData)
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }

        Text {
          id: shortcut

          anchors.right: parent.right
          anchors.rightMargin: Math.round(12 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          text: entry.index < 9 ? entry.index + 1 : ""
          color: Theme.overlay
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }

        MouseArea {
          id: entryMouse

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activate(entry.index)
        }
      }
    }
  }

  PlaceholderCard {
    shown: root.items.length === 0
    instant: true
    icon: "app-window"
    text: "No windows on this workspace"
  }
}
