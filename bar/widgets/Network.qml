import QtQuick
import Quickshell
import Quickshell.Networking
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  active: Panels.openOn("network", root.screen.name)

  onClicked: Panels.toggle("network", root.screen.name)
  onRightClicked: Networking.wifiEnabled = !Networking.wifiEnabled
  onMiddleClicked: Quickshell.execDetached(["bash", "-lc", "nmcli networking off; sleep 0.5; nmcli networking on"])

  readonly property bool enabled: Networking.wifiEnabled
  readonly property int connectivity: Networking.connectivity

  readonly property string glyph: {
    if (!enabled) {
      return "wifi-off"
    }
    if (connectivity === NetworkConnectivity.Full) {
      return "wifi-2"
    }
    if (connectivity === NetworkConnectivity.Portal) {
      return "wifi-1"
    }
    return "wifi-0"
  }

  Icon {
    anchors.centerIn: parent
    name: root.glyph
    color: root.enabled ? Theme.text : Theme.overlay
    font.pixelSize: Theme.iconSizeLarge
  }
}
