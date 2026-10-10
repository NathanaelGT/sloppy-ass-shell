import QtQuick
import "../theme"

Item {
  id: root

  property string title: ""
  default property alias actions: actionsRow.data

  implicitHeight: Math.round(30 * Theme.scale)
  height: implicitHeight
  width: parent ? parent.width : implicitWidth

  Text {
    anchors.left: parent.left
    anchors.right: actionsRow.left
    anchors.rightMargin: Math.round(8 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeLarge
    font.bold: true
    elide: Text.ElideRight
  }

  Row {
    id: actionsRow

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Math.round(6 * Theme.scale)
  }
}
