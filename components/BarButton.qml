import QtQuick
import "../theme"
import "../services"

Rectangle {
  id: root

  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheeled(int delta)

  property bool capsule: true
  property bool active: false
  property string panelKey: ""
  property color fill: capsule ? Theme.capsuleFill : "transparent"
  property color hoverFill: capsule ? Theme.capsuleHover : Theme.surface
  property color borderColor: "transparent"
  property int borderWidth: 0

  readonly property bool hovered: hoverHandler.hovered || mouse.containsMouse

  implicitHeight: capsule ? Theme.capsuleThickness : Theme.barThickness - Math.round(6 * Theme.scale)
  implicitWidth: implicitHeight
  height: implicitHeight
  width: implicitWidth
  radius: Theme.capsuleRadius
  color: hovered || active ? hoverFill : fill
  border.color: borderColor
  border.width: borderWidth
  antialiasing: true

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  HoverHandler {
    id: hoverHandler

    onHoveredChanged: if (hovered) {
      prewarmDwell.restart()
    } else {
      prewarmDwell.stop()
    }
  }

  Timer {
    id: prewarmDwell

    interval: 120
    onTriggered: if (root.panelKey.length > 0) {
      Panels.prewarm(root.panelKey)
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: e => e.button === Qt.LeftButton ? root.clicked() : e.button === Qt.RightButton ? root.rightClicked() : root.middleClicked()
    onWheel: e => root.wheeled(e.angleDelta.y)
  }
}
