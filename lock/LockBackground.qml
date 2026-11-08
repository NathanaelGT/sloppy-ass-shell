import QtQuick
import "../theme"

Item {
  id: root

  Rectangle {
    anchors.fill: parent
    color: Theme.base
    opacity: 0.6
    z: -1
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.3
  }
}
