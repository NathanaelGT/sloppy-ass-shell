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
  implicitHeight: Theme.barThickness + Theme.shadowPad

  readonly property bool laptop: screen.name === "eDP-1"
  readonly property int edgeMargin: laptop ? 0 : Theme.barMargin
  readonly property int cornerRadius: laptop ? 0 : Theme.barRadius
  readonly property bool reserveSpace: laptop
  readonly property bool autoHide: !laptop
  readonly property int barWidth: screen.width - edgeMargin * 2

  exclusiveZone: reserveSpace ? Theme.barThickness : 0
  exclusionMode: reserveSpace ? ExclusionMode.Normal : ExclusionMode.Ignore
  aboveWindows: !reserveSpace

  property bool revealed: false
  readonly property bool floatingPanel: Panels.panel === "session" || Panels.panel === "window-switcher"
  readonly property bool menuOpen: Panels.panel !== "" && !floatingPanel && Panels.screenName === screen.name
  readonly property bool shown: !autoHide || revealed || menuOpen || Panels.closingScreen === screen.name

  mask: Region {
    x: root.shown ? root.edgeMargin : 0
    y: 0
    width: root.shown ? root.barWidth : screen.width
    height: root.shown ? Theme.barThickness : Math.round(4 * Theme.scale)
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
    height: Theme.barThickness + Theme.shadowPad
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
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
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
        Notifications {
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
