import QtQuick
import Quickshell
import "../services"

Loader {
  id: root

  property string panelKey: ""
  property Component panelComponent: null

  readonly property bool requested: Panels.panel === panelKey
  readonly property bool prewarmed: panelKey.length > 0 && Panels.prewarmOn(panelKey)
  readonly property var modelData: Quickshell.screens.find(s => s.name === Panels.targetScreen) || null
  property bool grace: false
  active: requested || grace || prewarmed

  onRequestedChanged: {
    if (requested) {
      grace = true
      Panels.clearPrewarm()
      graceTimer.stop()
    } else if (item) {
      graceTimer.restart()
    }
  }

  Timer {
    id: graceTimer

    interval: 15000
    onTriggered: root.grace = false
  }

  sourceComponent: root.panelComponent
}
