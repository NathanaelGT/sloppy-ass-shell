pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland._IdleNotify

Singleton {
  id: root

  property var manual: null
  readonly property bool detected: monitor.enabled && monitor.isIdle
  readonly property bool active: root.manual !== null ? root.manual : root.detected

  IdleMonitor {
    id: monitor

    enabled: IdleConfig.loaded
    timeout: IdleConfig.idleSeconds
    respectInhibitors: true
  }
}
