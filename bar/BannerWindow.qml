import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"
import "widgets"

PanelWindow {
  id: root

  required property var modelData

  screen: modelData
  color: "transparent"
  anchors {
    top: true
    left: true
    right: true
  }
  implicitHeight: Theme.barThickness + Theme.bannerMaxExpand

  readonly property string screenId: modelData ? modelData.name : ""
  readonly property bool laptop: screenId === "eDP-1"
  readonly property var metrics: Panels.bannerMetricsFor(screenId)
  readonly property real bellRestX: metrics ? metrics.bellRestX : 0

  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  aboveWindows: true
  WlrLayershell.layer: WlrLayer.Overlay
  visible: laptop && Notifs.bannerVisible && !Hypr.fullscreen(screenId)

  Banner {
    id: banner

    x: root.bellRestX
    clockWidth: root.metrics ? root.metrics.clockWidth : 0
    bellWidth: root.metrics ? root.metrics.bellWidth : 0
    centerGap: Math.round(4 * Theme.scale)
    lobeHovered: root.metrics ? root.metrics.hovered : false
    screen: root.screen
  }

  readonly property var bellState: ({
      hovered: banner.hovered,
      separation: banner.separation,
      expand: banner.expand,
      lobeOpacity: banner.lobeOpacity
    })

  onBellStateChanged: Panels.setBannerBell(screenId, bellState)

  mask: Region {
    Region {
      x: banner.x + banner.compactLeft
      y: banner.pillY + banner.headerDrop
      width: Notifs.bannerPhase === "compact" || Notifs.bannerPhase === "expanded" ? banner.compactWidth : 0
      height: Notifs.bannerPhase === "compact" || Notifs.bannerPhase === "expanded" ? Theme.capsuleThickness : 0
    }

    Region {
      x: banner.x
      y: banner.pillY + Theme.capsuleThickness
      width: Notifs.bannerPhase === "expanded" ? Math.round(banner.blobWidth) : 0
      height: Notifs.bannerPhase === "expanded" ? Math.max(0, Math.round(banner.expand)) : 0
    }
  }
}
