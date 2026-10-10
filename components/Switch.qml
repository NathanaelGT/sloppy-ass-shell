import QtQuick
import "../theme"

Rectangle {
  id: root

  property bool checked: false
  property color accent: Theme.primary

  signal toggled()

  implicitWidth: Math.round(40 * Theme.scale)
  implicitHeight: Math.round(22 * Theme.scale)
  width: implicitWidth
  height: implicitHeight
  radius: height / 2
  color: checked ? accent : Theme.surfaceHigh
  antialiasing: true

  Behavior on color {
    ColorAnimation { duration: 140 }
  }

  Rectangle {
    id: knob

    y: Math.round(2 * Theme.scale)
    width: parent.height - Math.round(4 * Theme.scale)
    height: width
    radius: width / 2
    x: root.checked ? parent.width - width - Math.round(2 * Theme.scale) : Math.round(2 * Theme.scale)
    color: root.checked ? Theme.crust : Theme.text
    antialiasing: true

    Behavior on x {
      NumberAnimation {
        duration: 140
        easing.type: Easing.OutCubic
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
