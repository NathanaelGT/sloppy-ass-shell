import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  readonly property bool altTime: ClockState.showAltTime
  readonly property date displayDate: altTime ? new Date(clock.date.getTime() + 3600000) : clock.date

  implicitWidth: clockRow.implicitWidth + Math.round(26 * Theme.scale)
  active: Panels.openOn("dashboard", root.screen.name)
  onClicked: Panels.toggle("dashboard", root.screen.name)
  onRightClicked: ClockState.showAltTime = !ClockState.showAltTime

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  TextMetrics {
    id: witaMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "WITA"
  }

  TextMetrics {
    id: spaceMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: " "
  }

  Row {
    id: clockRow

    anchors.centerIn: parent
    spacing: spaceMetrics.advanceWidth

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.displayDate.toLocaleString(Theme.locale, "dddd, d MMMM yyyy  HH:mm:ss")
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      verticalAlignment: Text.AlignVCenter
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: witaMetrics.width
      horizontalAlignment: Text.AlignHCenter
      text: root.altTime ? "WITA" : root.displayDate.toLocaleString(Theme.locale, "t")
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      verticalAlignment: Text.AlignVCenter
    }
  }
}
