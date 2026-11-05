import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../components"
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
  implicitHeight: Theme.barThickness + Theme.shadowPad + Theme.bannerMaxExpand

  readonly property bool laptop: screen.name === "eDP-1"
  readonly property int edgeMargin: laptop ? 0 : Theme.barMargin
  readonly property int cornerRadius: laptop ? 0 : Theme.barRadius
  readonly property bool reserveSpace: laptop
  readonly property bool autoHide: !laptop
  readonly property int barWidth: screen.width - edgeMargin * 2
  readonly property int centerGap: Math.round(4 * Theme.scale)
  readonly property real clockRestX: Math.round((screen.width - clockWidget.fullWidth) / 2)
  readonly property real bellRestX: clockRestX - centerGap - notifWidget.width
  readonly property real musicRestX: clockRestX + clockWidget.fullWidth + centerGap
  readonly property bool musicMerged: musicWidget.showingTitle && !(root.laptop && Notifs.bannerVisible)
  readonly property int clusterWidth: (musicWidget.visible ? centerGap + musicWidget.width : 0) + clockWidget.fullWidth + centerGap + notifWidget.width
  readonly property int clusterRight: Math.round(bellRestX + clusterWidth)

  onClusterWidthChanged: Panels.setClusterWidth(screen.name, clusterWidth)
  onClusterRightChanged: Panels.setClusterRight(screen.name, clusterRight)
  Component.onCompleted: {
    Panels.setClusterWidth(screen.name, clusterWidth)
    Panels.setClusterRight(screen.name, clusterRight)
  }

  exclusiveZone: reserveSpace ? Theme.barThickness : 0
  exclusionMode: reserveSpace ? ExclusionMode.Normal : ExclusionMode.Ignore
  aboveWindows: true

  property bool revealed: false
  readonly property bool floatingPanel: Panels.panel === "window-switcher"
  readonly property bool menuOpen: Panels.panel !== "" && !floatingPanel && Panels.screenName === screen.name
  readonly property bool shown: !autoHide || revealed || menuOpen || Panels.closingScreen === screen.name || notifWidget.merging

  mask: Region {
    x: root.shown ? root.edgeMargin : 0
    y: 0
    width: root.shown ? root.barWidth : screen.width
    height: root.shown ? Theme.barThickness : Math.round(4 * Theme.scale)

    Region {
      x: bannerWidget.x
      y: Theme.barThickness
      width: root.laptop && Notifs.bannerPhase === "expanded" ? Math.round(bannerWidget.restWidth) : 0
      height: root.laptop && Notifs.bannerPhase === "expanded" ? Math.max(0, bannerWidget.pillY + Theme.capsuleThickness + bannerWidget.expandTarget - Theme.barThickness) : 0
    }
  }

  Process {
    id: cursorProc
    command: ["hyprctl", "cursorpos", "-j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const pos = JSON.parse(text)
          const nearTop = pos.x >= screen.x + root.edgeMargin && pos.x < screen.x + root.edgeMargin + root.barWidth && pos.y >= screen.y - Math.round(2 * Theme.scale) && pos.y < screen.y + Math.round(3 * Theme.scale)
          const overBar = root.shown && pos.x >= screen.x + root.edgeMargin && pos.x < screen.x + root.edgeMargin + root.barWidth && pos.y >= screen.y && pos.y < screen.y + Theme.barThickness
          root.revealed = nearTop || overBar
          Panels.barHoverScreen = overBar ? screen.name : (Panels.barHoverScreen === screen.name ? "" : Panels.barHoverScreen)
        } catch (e) {}
      }
    }
  }
  Item {
    id: visual
    x: 0
    width: screen.width
    height: Theme.barThickness + Theme.shadowPad + Theme.bannerMaxExpand
    y: root.shown ? 0 : -height
    layer.enabled: true
    layer.samples: 4

    Behavior on y {
      NumberAnimation {
        duration: 200
        easing.type: Easing.OutCubic
      }
    }

    BarSurface {
      id: barSurface

      x: 0
      y: 0
      width: screen.width
      height: Theme.barThickness
      surfaceColor: Theme.base
      edgeMargin: root.edgeMargin
      cornerRadius: root.cornerRadius
      barWidth: root.barWidth
      barHeight: Theme.barThickness
      visible: false
    }

    PanelShadow {
      shadowSource: barSurface
    }

    Item {
      id: barArea

      x: 0
      y: 0
      width: screen.width
      height: Theme.barThickness

      Taskbar {
        x: root.edgeMargin + Math.round(6 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
      }

      Clock {
        id: clockWidget

        x: root.clockRestX
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
        merged: root.laptop && Notifs.bannerVisible
      }

      Music {
        id: musicWidget

        x: musicWidget.merged ? root.clockRestX : root.musicRestX
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
        merged: root.musicMerged
        mergedSpan: clockWidget.fullWidth + root.centerGap
      }

      Notifications {
        id: notifWidget

        x: root.laptop && Notifs.bannerVisible ? bannerWidget.x : root.bellRestX
        anchors.verticalCenter: parent.verticalCenter
        screen: root.screen
        merged: root.laptop && Notifs.bannerVisible
        bannerIcon: bannerWidget.appIconSource
        bannerIconLeft: bannerWidget.pad
        bannerIconDrop: bannerWidget.headerDrop
      }

      Banner {
        id: bannerWidget

        x: root.bellRestX
        y: 0
        z: -1
        clockWidth: clockWidget.fullWidth
        bellWidth: notifWidget.width
        centerGap: root.centerGap
        lobeHovered: clockWidget.hovered || notifWidget.hovered
        screen: root.screen
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: root.edgeMargin + Math.round(6 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(4 * Theme.scale)

        Tray {
          screen: root.screen
        }
        Network {
          screen: root.screen
        }
        Bluetooth {
          screen: root.screen
        }
        Volume {
          screen: root.screen
        }
        Battery {
          screen: root.screen
        }
      }
    }
  }

  Timer {
    interval: root.menuOpen ? 120 : 250
    running: root.autoHide || root.menuOpen
    repeat: true
    onTriggered: cursorProc.running = true
  }
}
