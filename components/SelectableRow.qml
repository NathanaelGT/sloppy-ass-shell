import QtQuick
import "../theme"

Rectangle {
  id: root

  property string title: ""
  property bool active: false
  property bool boldTitle: false
  property int rowHeight: Math.round(44 * Theme.scale)
  property int actionSpacing: Math.round(6 * Theme.scale)
  property int actionMargin: Math.round(8 * Theme.scale)

  signal clicked()

  default property alias actions: actionsRow.data
  property alias leading: leadingHost.data

  width: parent ? parent.width : 0
  height: rowHeight
  radius: Theme.rowRadius
  color: active || mouse.containsMouse ? Theme.surfaceHigh : Theme.surface
  antialiasing: true

  Item {
    id: leadingHost

    anchors.left: parent.left
    anchors.leftMargin: Math.round(12 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    width: children.length > 0 ? children[0].width : 0
    height: children.length > 0 ? children[0].height : 0
  }

  Text {
    id: titleText

    anchors.left: leadingHost.right
    anchors.leftMargin: Math.round(10 * Theme.scale)
    anchors.right: actionsRow.left
    anchors.rightMargin: Math.round(8 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: root.active ? Theme.primary : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: root.boldTitle
    elide: Text.ElideRight
  }

  Row {
    id: actionsRow

    anchors.right: parent.right
    anchors.rightMargin: root.actionMargin
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.actionSpacing
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
