import QtQuick
import "../theme"

Rectangle {
  id: root

  property string name: ""
  property color iconColor: Theme.text
  property color hoverColor: Theme.surfaceHigh
  property int size: Math.round(30 * Theme.scale)

  signal clicked()

  implicitWidth: size
  implicitHeight: size
  radius: size / 2
  color: mouse.containsMouse ? hoverColor : "transparent"
  antialiasing: true

  Icon {
    anchors.centerIn: parent
    name: root.name
    color: root.iconColor
    font.pixelSize: Theme.iconSize
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
