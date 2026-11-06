import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "power"
  align: "center"
  cardWidth: Math.round(Theme.panelWidth * 0.5)
  exclusiveFocus: true

  readonly property int rowHeight: Math.round(48 * Theme.scale)
  readonly property int holdMs: 750
  readonly property int drainMs: 150
  readonly property int iconInset: Math.round(12 * Theme.scale)
  readonly property int iconSlotSize: Math.round(24 * Theme.scale)
  readonly property int textGap: Math.round(12 * Theme.scale)
  property int focusRow: 0
  property int keyboardHoldRow: -1

  readonly property var actions: [
    {
      icon: "lock",
      label: "Lock",
      tint: Theme.primary,
      lock: true
    },
    {
      icon: "suspend",
      label: "Lock & Suspend",
      tint: Theme.mauve,
      suspend: true
    },
    {
      icon: "restart",
      label: "Reboot",
      tint: Theme.yellow,
      command: ["bash", "-lc", "hyprshutdown -p 'setterm --blank force && systemctl reboot'"]
    },
    {
      icon: "shutdown",
      label: "Shutdown",
      tint: Theme.red,
      command: ["bash", "-lc", "hyprshutdown -p 'setterm --blank force && systemctl poweroff'"]
    }
  ]

  function run(index) {
    const action = root.actions[index]
    if (!action) {
      return
    }
    Panels.close()
    if (action.lock) {
      LockState.requestLock()
      return
    }
    if (action.suspend) {
      LockState.lockAndSuspend()
      return
    }
    Quickshell.execDetached(action.command)
  }

  function moveFocus(delta) {
    root.focusRow = (root.focusRow + delta + root.actions.length) % root.actions.length
  }

  function cancelHolds() {
    root.keyboardHoldRow = -1
    for (let i = 0; i < root.actions.length; i++) {
      const row = rowRepeater.itemAt(i)
      if (row) {
        row.cancelHold()
      }
    }
  }

  onOpened: {
    root.focusRow = 0
    root.cancelHolds()
  }

  onKeyPressed: event => {
    if (event.key === Qt.Key_Up) {
      root.moveFocus(-1)
      event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      root.moveFocus(1)
      event.accepted = true
    } else if (event.key === Qt.Key_F1) {
      if (!event.isAutoRepeat) {
        root.run(0)
      }
      event.accepted = true
    } else if (event.key >= Qt.Key_F2 && event.key <= Qt.Key_F4) {
      if (!event.isAutoRepeat) {
        const row = rowRepeater.itemAt(event.key - Qt.Key_F2 + 1)
        if (row) {
          row.beginHold()
        }
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (!event.isAutoRepeat) {
        if (root.focusRow === 0) {
          root.run(0)
        } else {
          root.keyboardHoldRow = root.focusRow
          const row = rowRepeater.itemAt(root.focusRow)
          if (row) {
            row.beginHold()
          }
        }
      }
      event.accepted = true
    }
  }

  onKeyReleased: event => {
    if (event.isAutoRepeat) {
      return
    }
    if (event.key >= Qt.Key_F2 && event.key <= Qt.Key_F4) {
      const row = rowRepeater.itemAt(event.key - Qt.Key_F2 + 1)
      if (row) {
        row.endHold()
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.keyboardHoldRow >= 0) {
        const row = rowRepeater.itemAt(root.keyboardHoldRow)
        if (row) {
          row.endHold()
        }
        root.keyboardHoldRow = -1
      }
      event.accepted = true
    }
  }

  Repeater {
    id: rowRepeater

    model: root.actions

    delegate: Item {
      id: row

      required property var modelData
      required property int index

      readonly property bool instant: index === 0
      readonly property bool hot: rowMouse.containsMouse || root.focusRow === index
      property real progress: 0
      property bool holding: false

      function beginHold() {
        if (!root.open) {
          return
        }
        holding = true
      }

      function endHold() {
        holding = false
      }

      function cancelHold() {
        holding = false
        progress = 0
      }

      width: parent.width
      height: root.rowHeight

      Timer {
        interval: 16
        repeat: true
        running: row.holding || row.progress > 0
        onTriggered: {
          if (!root.open) {
            row.cancelHold()
            return
          }
          if (row.holding) {
            row.progress = Math.min(1, row.progress + interval / root.holdMs)
            if (row.progress >= 1) {
              row.cancelHold()
              root.run(row.index)
            }
          } else {
            row.progress = Math.max(0, row.progress - interval / root.drainMs)
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Theme.rowRadius
        color: row.hot ? Theme.surface : "transparent"

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          radius: Theme.rowRadius
          color: Theme.primary
          opacity: 0.25
          visible: row.progress > 0
          width: Math.max(0, Math.min(parent.width, row.progress * parent.width))
        }
      }

      Item {
        id: iconSlot

        anchors.left: parent.left
        anchors.leftMargin: root.iconInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSlotSize
        height: width

        Icon {
          anchors.centerIn: parent
          name: row.modelData.icon
          color: row.modelData.tint
          font.pixelSize: Math.round(20 * Theme.scale)
        }
      }

      Text {
        anchors.left: iconSlot.right
        anchors.leftMargin: root.textGap
        anchors.right: parent.right
        anchors.rightMargin: root.iconInset
        anchors.verticalCenter: parent.verticalCenter
        text: row.modelData.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
      }

      MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
          if (mouse.button === Qt.LeftButton && !row.instant) {
            row.beginHold()
          }
        }
        onReleased: mouse => {
          if (mouse.button === Qt.LeftButton && !row.instant) {
            row.endHold()
          }
        }
        onCanceled: if (!row.instant) {
          row.endHold()
        }
        onClicked: mouse => {
          if (row.instant) {
            root.run(row.index)
          }
        }
      }
    }
  }
}
