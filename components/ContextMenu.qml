import QtQuick
import QtQuick.Controls
import "../theme"

Popup {
  id: root

  property var entries: []
  property string title: ""
  property int armedIndex: -1
  readonly property int rowH: Math.round(22 * Theme.scale)
  readonly property int titleH: Math.round(24 * Theme.scale)

  width: Math.round(196 * Theme.scale)
  height: menuColumn.implicitHeight + padding * 2
  padding: Math.round(3 * Theme.scale)
  popupType: Popup.Item
  modal: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  enter: Transition {
    NumberAnimation {
      property: "opacity"
      from: 0
      to: 1
      duration: 140
      easing.type: Easing.OutCubic
    }
  }

  exit: Transition {
    NumberAnimation {
      property: "opacity"
      from: 1
      to: 0
      duration: 120
      easing.type: Easing.OutCubic
    }
  }

  onOpened: root.armedIndex = -1
  onClosed: root.armedIndex = -1

  function openAt(x, y, items) {
    root.entries = items
    root.armedIndex = -1
    root.x = x
    root.y = y
    root.open()
  }

  function trackHover(wx, wy) {
    if (!root.opened) {
      return
    }
    const pad = Math.round(3 * Theme.scale)
    if (wx < root.x - pad || wx > root.x + root.width + pad || wy < root.y - pad || wy > root.y + root.height + pad) {
      root.close()
    }
  }

  function invoke(index) {
    const entry = root.entries[index]
    if (!entry || entry.separator === true) {
      return ""
    }
    if (entry.confirm === true && root.armedIndex !== index) {
      root.armedIndex = index
      armTimer.restart()
      return "armed"
    }
    root.close()
    if (entry.action !== undefined) {
      entry.action()
    }
    return "done"
  }

  Timer {
    id: armTimer

    interval: 2500
    onTriggered: root.armedIndex = -1
  }

  background: Rectangle {
    color: Theme.surfaceHigh
    radius: Theme.rowRadius
    border.width: 1
    border.color: Theme.surfaceHigher
    antialiasing: true
  }

  contentItem: Column {
    id: menuColumn

    spacing: Math.round(1 * Theme.scale)

    Text {
      width: menuColumn.width
      height: root.title !== "" ? root.titleH : 0
      visible: root.title !== ""
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: root.title
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(10 * Theme.scale)
      font.bold: true
      elide: Text.ElideRight
    }

    Rectangle {
      width: menuColumn.width
      height: root.title !== "" ? Math.round(1 * Theme.scale) : 0
      visible: root.title !== ""
      color: Theme.surfaceHigher
    }

    Repeater {
      model: root.entries

      delegate: Item {
        id: entryRow

        required property int index
        required property var modelData

        readonly property bool separator: modelData.separator === true
        readonly property bool armed: root.armedIndex === index

        width: menuColumn.width
        height: entryRow.separator ? Math.round(1 * Theme.scale) : root.rowH

        Rectangle {
          anchors.fill: parent
          visible: !entryRow.separator
          radius: Math.round(6 * Theme.scale)
          color: entryRow.armed ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.3) : entryMouse.containsMouse ? Theme.surfaceHigher : "transparent"
          antialiasing: true
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: Math.round(1 * Theme.scale)
          visible: entryRow.separator
          color: Theme.surfaceHigher
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Math.round(8 * Theme.scale)
          anchors.right: parent.right
          anchors.rightMargin: Math.round(8 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          visible: !entryRow.separator
          text: {
            const entry = entryRow.modelData
            if (entryRow.armed) {
              return "Confirm " + entry.label.charAt(0).toLowerCase() + entry.label.slice(1)
            }
            return entry.labelFn !== undefined ? entry.labelFn() : entry.label
          }
          color: entryRow.modelData.danger === true || entryRow.armed ? Theme.red : Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Math.round(9 * Theme.scale)
          elide: Text.ElideRight
        }

        MouseArea {
          id: entryMouse

          anchors.fill: parent
          enabled: !entryRow.separator
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.invoke(entryRow.index)
        }
      }
    }
  }
}
