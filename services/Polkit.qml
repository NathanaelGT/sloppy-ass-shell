pragma Singleton
import Quickshell
import Quickshell.Services.Polkit

Singleton {
  id: root

  readonly property alias agent: instance
  readonly property var flow: instance.flow
  readonly property bool active: instance.isActive && instance.flow !== null
  property string targetScreen: ""
  property var lastFlow: null
  readonly property string pinScreen: {
    const screens = Quickshell.screens
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name === targetScreen) {
        return targetScreen
      }
    }
    return Hypr.focusedScreenName
  }

  PolkitAgent {
    id: instance

    onFlowChanged: {
      if (instance.flow !== root.lastFlow) {
        root.targetScreen = instance.flow === null ? "" : Hypr.focusedScreenName
        root.lastFlow = instance.flow
      }
    }
  }
}
