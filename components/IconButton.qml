import QtQuick
import "../theme"

Rectangle {
  id: root

  property string name: ""
  property color iconColor: Theme.text
  property color hoverColor: Theme.surfaceHigh
  property int size: Math.round(30 * Theme.scale)
  property int glyphSize: Theme.iconSize
  property bool hovered: mouse.containsMouse
  property bool spinning: false

  signal clicked

  onSpinningChanged: {
    if (root.spinning) {
      finishAnim.stop()
    } else {
      root.finishSpin()
    }
  }

  function finishSpin() {
    const pos = ((icon.rotation % 360) + 360) % 360
    if (pos < 0.5) {
      icon.rotation = 0
      return
    }
    finishAnim.from = icon.rotation
    finishAnim.to = icon.rotation + (360 - pos)
    finishAnim.duration = Math.round((360 - pos) / 360 * 1000)
    finishAnim.restart()
  }

  implicitWidth: size
  implicitHeight: size
  radius: size / 2
  color: mouse.containsMouse ? hoverColor : "transparent"
  antialiasing: true

  Icon {
    id: icon

    anchors.centerIn: parent
    name: root.name
    color: root.iconColor
    font.pixelSize: root.glyphSize

    RotationAnimator on rotation {
      from: 0
      to: 360
      duration: 1000
      loops: Animation.Infinite
      running: root.spinning
    }

    NumberAnimation on rotation {
      id: finishAnim

      easing.type: Easing.Linear
      onStopped: if (!root.spinning) {
        icon.rotation = 0
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
