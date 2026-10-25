import QtQuick
import Quickshell.Services.UPower
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  implicitWidth: timeLabel.visible ? icon.implicitWidth + Math.round(5 * Theme.scale) + timeLabel.implicitWidth + Math.round(16 * Theme.scale) : icon.implicitWidth + Math.round(16 * Theme.scale)
  active: Panels.openOn("battery", root.screen.name)
  onClicked: Panels.toggle("battery", root.screen.name)

  readonly property var device: UPower.displayDevice
  readonly property real pct: device ? device.percentage : 1
  readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged) : false
  readonly property bool full: device ? (device.state === UPowerDeviceState.FullyCharged || pct >= 0.995) : true

  visible: device !== null && device.isPresent

  readonly property color tint: charging ? Theme.green : pct <= 0.15 ? Theme.red : pct <= 0.3 ? Theme.yellow : Theme.text

  function formatTime(seconds) {
    if (!seconds || seconds <= 0) {
      return ""
    }
    const total = Math.round(seconds / 60)
    const h = Math.floor(total / 60)
    const m = total % 60
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }

  BatteryIcon {
    id: icon
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Math.round(10 * Theme.scale)
    level: root.pct
    color: root.tint
  }

  Text {
    id: timeLabel
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: icon.right
    anchors.leftMargin: Math.round(5 * Theme.scale)
    visible: text.length > 0
    text: root.charging ? root.formatTime(root.device ? root.device.timeToFull : 0) : root.formatTime(root.device ? root.device.timeToEmpty : 0)
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
  }
}
