import QtQuick
import "../theme"

Item {
  id: root

  property real level: 0
  property color color: Theme.text

  implicitWidth: root.bodyWidth + root.termWidth
  implicitHeight: Math.round(16 * Theme.scale)

  readonly property real clamped: Math.max(0, Math.min(1, root.level))
  readonly property int bodyWidth: Math.round(implicitHeight * 1.75)
  readonly property int termWidth: Math.round(implicitHeight * 0.15)
  readonly property int bodyRadius: Math.round(3 * Theme.scale)
  readonly property int borderWidth: Math.max(1, Math.round(1.5 * Theme.scale))
  readonly property int fillRadius: Math.max(0, bodyRadius - borderWidth)

  Rectangle {
    id: body
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    width: root.bodyWidth
    height: root.implicitHeight
    radius: root.bodyRadius
    color: "transparent"
    border.color: root.color
    border.width: root.borderWidth
    antialiasing: true

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: root.borderWidth
      anchors.topMargin: root.borderWidth
      width: Math.max(0, (parent.width - root.borderWidth * 2) * root.clamped)
      height: parent.height - root.borderWidth * 2
      radius: root.fillRadius
      color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.2)
      antialiasing: true
    }

    Text {
      anchors.centerIn: parent
      text: Math.round(root.clamped * 100)
      color: root.color
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(9 * Theme.scale)
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: body.right
    width: root.termWidth
    height: Math.round(root.implicitHeight * 0.5)
    radius: Math.round(1 * Theme.scale)
    color: root.color
    antialiasing: true
  }
}
