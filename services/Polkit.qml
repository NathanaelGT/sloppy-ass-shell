pragma Singleton
import Quickshell
import Quickshell.Services.Polkit

Singleton {
  readonly property alias agent: instance
  readonly property var flow: instance.flow
  readonly property bool active: instance.isActive && instance.flow !== null

  PolkitAgent {
    id: instance
  }
}
