import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  active: Panels.openOn("bluetooth", root.screen.name)

  onClicked: Panels.toggle("bluetooth", root.screen.name)
  onRightClicked: {
    if (adapter) {
      adapter.enabled = !adapter.enabled
    }
  }
  onMiddleClicked: Quickshell.execDetached(["bash", "-lc", "bluetoothctl power off; sleep 0.5; bluetoothctl power on"])

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool on: adapter ? adapter.enabled : false
  readonly property bool connected: {
    if (!adapter) {
      return false
    }
    const devices = adapter.devices.values ? adapter.devices.values : adapter.devices
    for (let i = 0; i < devices.length; i++) {
      if (devices[i].connected) {
        return true
      }
    }
    return false
  }

  visible: on

  Icon {
    anchors.centerIn: parent
    name: root.connected ? "bluetooth-connected" : "bluetooth"
    color: root.connected ? Theme.primary : Theme.text
    font.pixelSize: Theme.iconSizeLarge
  }
}
