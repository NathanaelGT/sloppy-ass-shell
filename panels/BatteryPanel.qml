import QtQuick
import Quickshell.Services.UPower
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "battery"

  readonly property var device: UPower.displayDevice
  readonly property real pct: device ? device.percentage : 0
  readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged) : false

  function stateLabel() {
    if (!device) {
      return "Unknown"
    }
    if (device.state === UPowerDeviceState.Charging) {
      return "Charging"
    }
    if (device.state === UPowerDeviceState.Discharging) {
      return "Discharging"
    }
    if (device.state === UPowerDeviceState.FullyCharged) {
      return "Full"
    }
    if (device.state === UPowerDeviceState.Empty) {
      return "Empty"
    }
    return "Unknown"
  }

  function formatTime(seconds) {
    if (!seconds || seconds <= 0) {
      return "—"
    }
    const total = Math.round(seconds / 60)
    const h = Math.floor(total / 60)
    const m = total % 60
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }

  PanelHeader {
    title: "Battery"
  }

  Row {
    width: parent.width
    spacing: Theme.gap

    Icon {
      anchors.verticalCenter: parent.verticalCenter
      name: {
        if (root.charging) {
          return "battery-charging"
        }
        if (root.pct > 0.85) {
          return "battery-4"
        }
        if (root.pct > 0.6) {
          return "battery-3"
        }
        if (root.pct > 0.35) {
          return "battery-2"
        }
        return "battery-1"
      }
      color: root.pct <= 0.15 ? Theme.red : root.pct <= 0.3 ? Theme.yellow : Theme.text
      font.pixelSize: Math.round(28 * Theme.scale)
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Math.round(2 * Theme.scale)

      Text {
        text: Math.round(root.pct * 100) + "%"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
      }

      Text {
        text: root.stateLabel()
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
      }
    }
  }

  Repeater {
    model: root.device ? [
      {
        label: "Time",
        value: root.charging ? root.formatTime(root.device.timeToFull) : root.formatTime(root.device.timeToEmpty)
      },
      {
        label: "Health",
        value: root.device.healthSupported ? Math.round(root.device.healthPercentage) + "%" : "—"
      },
      {
        label: "Model",
        value: root.device.model && root.device.model.length > 0 ? root.device.model : "—"
      }
    ] : []

    delegate: Row {
      required property var modelData

      width: root.contentWidth
      height: Math.round(28 * Theme.scale)

      Text {
        width: parent.width / 2
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.label
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
      }

      Text {
        width: parent.width / 2
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }
    }
  }
}
