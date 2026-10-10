import QtQuick
import Quickshell.Services.UPower
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen
  property bool hideWhenFull: true

  implicitWidth: timeLabel.visible ? timeLabel.implicitWidth + Math.round(38 * Theme.scale) : Math.round(34 * Theme.scale)
  active: Panels.openOn("battery", root.screen.name)
  onClicked: Panels.toggle("battery", root.screen.name)

  readonly property var device: UPower.displayDevice
  readonly property real pct: device ? device.percentage : 1
  readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged) : false
  readonly property bool full: device ? (device.state === UPowerDeviceState.FullyCharged || pct >= 0.995) : true

  visible: device !== null && device.isPresent && !(full && hideWhenFull)

  readonly property string glyph: {
    if (charging) return "battery-charging";
    if (pct > 0.85) return "battery-4";
    if (pct > 0.6) return "battery-3";
    if (pct > 0.35) return "battery-2";
    return "battery-1";
  }

  readonly property color tint: charging ? Theme.green : pct <= 0.15 ? Theme.red : pct <= 0.3 ? Theme.yellow : Theme.text

  function formatTime(seconds) {
    if (!seconds || seconds <= 0) return "";
    const total = Math.round(seconds / 60);
    const h = Math.floor(total / 60);
    const m = total % 60;
    return h > 0 ? h + "h " + m + "m" : m + "m";
  }

  Icon {
    id: icon
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Math.round(7 * Theme.scale)
    name: root.glyph
    color: root.tint
    font.pixelSize: Theme.iconSizeLarge
  }

  Text {
    id: timeLabel
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: icon.right
    anchors.leftMargin: Math.round(4 * Theme.scale)
    visible: text.length > 0
    text: root.charging ? root.formatTime(root.device ? root.device.timeToFull : 0) : root.formatTime(root.device ? root.device.timeToEmpty : 0)
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
  }
}
