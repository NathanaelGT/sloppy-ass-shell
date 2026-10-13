import QtQuick
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  active: Panels.openOn("notifications", root.screen.name)

  onClicked: Panels.toggle("notifications", root.screen.name)
  onRightClicked: Notifs.dnd = !Notifs.dnd
  onMiddleClicked: Notifs.dismissAll()

  readonly property int count: {
    const list = Notifs.active
    return list && typeof list.length === "number" ? list.length : 0
  }

  Icon {
    anchors.centerIn: parent
    name: Notifs.dnd ? "bell-off" : root.count > 0 ? "bell-ringing" : "bell"
    color: Notifs.dnd ? Theme.yellow : root.count > 0 ? Theme.primary : Theme.text
    font.pixelSize: Theme.iconSizeLarge
  }

  Rectangle {
    visible: root.count > 0
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Math.round(4 * Theme.scale)
    width: Math.max(Math.round(16 * Theme.scale), badge.implicitWidth + Math.round(8 * Theme.scale))
    height: Math.round(16 * Theme.scale)
    radius: height / 2
    color: Theme.red

    Text {
      id: badge
      anchors.centerIn: parent
      text: root.count
      color: Theme.crust
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      font.bold: true
    }
  }
}
