import QtQuick
import "../theme"

Item {
  id: root

  property string label: ""
  property string section: ""
  property bool expanded: true

  signal toggleRequested

  implicitHeight: Math.round(20 * Theme.scale)
  height: implicitHeight
  width: parent ? parent.width : 0

  SectionHeader {
    anchors.fill: parent
    label: root.label

    IconButton {
      size: Math.round(20 * Theme.scale)
      name: root.expanded ? "chevron-up" : "chevron-down"
      iconColor: Theme.overlay
      onClicked: root.toggleRequested()
    }
  }
}
