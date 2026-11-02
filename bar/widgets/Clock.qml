import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen
  property bool merged: false

  readonly property bool altTime: ClockState.showAltTime
  readonly property date displayDate: altTime ? new Date(clock.date.getTime() + 3600000) : clock.date
  readonly property string dateText: root.displayDate.toLocaleString(Theme.locale, "dddd, d MMMM yyyy")
  readonly property string timeText: root.displayDate.toLocaleString(Theme.locale, "HH:mm:ss")
  readonly property string zoneText: root.altTime ? "WITA" : root.displayDate.toLocaleString(Theme.locale, "t")
  readonly property int fullWidth: Math.round(dateMetrics.advanceWidth + spaceMetrics.advanceWidth * 3 + timeSlotWidth + witaMetrics.width + 26 * Theme.scale)

  implicitWidth: root.fullWidth
  fill: root.merged ? Qt.rgba(Theme.capsuleFill.r, Theme.capsuleFill.g, Theme.capsuleFill.b, 0) : Theme.capsuleFill
  enabled: !root.merged
  hoverFill: Theme.capsuleHover
  active: Panels.openOn("dashboard", root.screen.name)
  onClicked: {
    if (Notifs.bannerVisible) {
      Notifs.acknowledgeBanner()
    }
    Panels.toggle("dashboard", root.screen.name)
  }
  onRightClicked: ClockState.showAltTime = !ClockState.showAltTime

  Connections {
    target: Notifs

    function onBannerPhaseChanged() {
      if (Notifs.bannerPhase === "compact" || Notifs.bannerPhase === "expanded") {
        clockTextShowAnim.stop()
        clockTextHideAnim.restart()
        return
      }
      clockTextHideAnim.stop()
      clockTextShowAnim.restart()
    }
  }

  NumberAnimation {
    id: clockTextHideAnim

    target: clockRow
    property: "opacity"
    to: 0
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: clockTextShowAnim

    target: clockRow
    property: "opacity"
    to: 1
    duration: 280
    easing.type: Easing.InOutSine
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  TextMetrics {
    id: dateMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: root.dateText
  }

  TextMetrics {
    id: timeMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "88:88:88"
  }

  readonly property int timeSlotWidth: Math.max(Math.round(timeMetrics.advanceWidth), Math.round(spaceMetrics.advanceWidth))

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

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.dateText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
      }

      Item {
        width: spaceMetrics.advanceWidth * 2
        height: 1
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.timeSlotWidth
        text: root.timeText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: witaMetrics.width
      horizontalAlignment: Text.AlignHCenter
      text: root.zoneText
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      verticalAlignment: Text.AlignVCenter
    }
  }
}
