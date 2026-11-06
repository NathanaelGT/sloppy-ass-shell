import QtQuick
import "../theme"

Rectangle {
  id: root

  property bool hovered: false
  property real pad: Math.round(3 * Theme.scale)

  x: -root.pad
  y: -root.pad
  width: parent.width + root.pad * 2
  height: parent.height + root.pad * 2
  radius: height / 2
  color: root.hovered ? Theme.capsuleHover : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }
}
