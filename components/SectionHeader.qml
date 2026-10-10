import QtQuick
import "../theme"

Item {
  id: root

  property string label: ""
  default property alias actions: actionsRow.data

  implicitHeight: Math.round(20 * Theme.scale)
  height: implicitHeight
  width: parent ? parent.width : implicitWidth

  SectionLabel {
    anchors.left: parent.left
    anchors.leftMargin: Math.round(4 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    label: root.label
  }

  Row {
    id: actionsRow

    anchors.right: parent.right
    anchors.rightMargin: Math.round(4 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Math.round(2 * Theme.scale)
  }
}
