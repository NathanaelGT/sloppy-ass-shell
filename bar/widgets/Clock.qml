import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  implicitWidth: label.implicitWidth + Math.round(26 * Theme.scale)
  active: Panels.openOn("control-center", root.screen.name)
  onClicked: Panels.toggle("control-center", root.screen.name)
  onRightClicked: Panels.toggle("control-center", root.screen.name)

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: clock.date.toLocaleString(Theme.locale, "dddd, dd MMMM yyyy  HH:mm:ss  t")
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
  }
}
