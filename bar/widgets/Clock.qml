import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen
  panelKey: "dashboard"
  property bool merged: false

  readonly property bool altTime: ClockState.showAltTime
  readonly property int fullWidth: Math.round(face.contentWidth + 26 * Theme.scale)
  readonly property real clockOpacity: face.opacity

  Component.onCompleted: TestDriver.register("clockPill", root.screen.name, root)

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
      if (root.screen.name !== "eDP-1") {
        return
      }
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

    target: face
    property: "opacity"
    to: 0
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: clockTextShowAnim

    target: face
    property: "opacity"
    to: 1
    duration: 280
    easing.type: Easing.InOutSine
  }

  ClockFace {
    id: face

    anchors.centerIn: parent
  }
}
