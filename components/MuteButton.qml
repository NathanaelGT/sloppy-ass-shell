import QtQuick
import "../theme"

Rectangle {
  id: root

  property bool muted: false
  property bool dormant: false
  property real level: 0
  property real maxLevel: 1.5
  property string kind: "output"

  signal clicked
  signal wheeled(real angleDelta)

  implicitWidth: Math.round(20 * Theme.scale)
  implicitHeight: implicitWidth
  radius: width / 2
  color: mouse.containsMouse ? Theme.surfaceHigh : "transparent"
  antialiasing: true

  VolumeIcon {
    visible: root.kind === "output" && !root.muted
    anchors.centerIn: parent
    width: Theme.iconSize
    height: Theme.iconSize
    level: root.level
    maxLevel: root.maxLevel
    color: Theme.text
  }

  Icon {
    visible: root.kind === "output" && root.muted
    anchors.centerIn: parent
    name: "volume-off"
    color: Theme.red
    font.pixelSize: Math.round(13 * Theme.scale)
  }

  Icon {
    visible: root.kind === "input"
    anchors.centerIn: parent
    name: root.muted ? "microphone-off" : "microphone"
    color: root.muted ? Theme.red : root.dormant ? Theme.overlay : Theme.text
    font.pixelSize: Math.round(13 * Theme.scale)
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    onWheel: e => {
      root.wheeled(e.angleDelta.y)
      e.accepted = true
    }
  }
}
