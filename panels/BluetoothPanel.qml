import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "bluetooth"

  property string expandedAddress: ""

  readonly property var adapter: Bluetooth.defaultAdapter

  readonly property var devices: {
    if (!adapter || !adapter.devices) {
      return []
    }
    const list = adapter.devices.values ? adapter.devices.values : adapter.devices
    const out = []
    for (let i = 0; i < list.length; i++) {
      const d = list[i]
      if (d.paired || d.bonded || d.connected) {
        out.push(d)
      }
    }
    out.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
    return out
  }

  function refresh() {
    if (adapter) {
      adapter.discovering = true
    }
  }

  function remove(device) {
    Quickshell.execDetached(["bluetoothctl", "remove", device.address])
  }

  onOpened: {
    refresh()
    expandedAddress = ""
  }

  PanelHeader {
    title: "Bluetooth"

    IconButton {
      name: "refresh"
      onClicked: root.refresh()
    }

    Switch {
      checked: root.adapter ? root.adapter.enabled : false
      onToggled: if (root.adapter) {
        root.adapter.enabled = !root.adapter.enabled
      }
    }
  }

  Rectangle {
    width: parent.width
    height: Math.round(44 * Theme.scale)
    radius: Theme.rowRadius
    color: Theme.surface
    antialiasing: true

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Math.round(14 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: discoverSwitch.left
      anchors.rightMargin: Math.round(8 * Theme.scale)
      text: "Discoverable by nearby devices"
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      elide: Text.ElideRight
    }

    Switch {
      id: discoverSwitch

      anchors.right: parent.right
      anchors.rightMargin: Math.round(10 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      checked: root.adapter ? root.adapter.discoverable : false
      onToggled: if (root.adapter) {
        root.adapter.discoverable = !root.adapter.discoverable
      }
    }
  }

  SectionLabel {
    label: "Paired"
    anchors.left: parent.left
    anchors.leftMargin: Math.round(4 * Theme.scale)
  }

  Text {
    visible: root.devices.length === 0
    width: parent.width
    text: "No devices"
    color: Theme.overlay
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignHCenter
  }

  Repeater {
    model: root.devices

    delegate: Item {
      id: entry

      required property var modelData

      readonly property bool expanded: root.expandedAddress === modelData.address
      readonly property bool connecting: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

      width: root.contentWidth
      height: rowRect.height + (expanded ? expandedColumn.height + Math.round(6 * Theme.scale) : 0)

      SelectableRow {
        id: rowRect

        active: entry.modelData.connected
        rowHeight: Math.round(46 * Theme.scale)
        actionSpacing: Math.round(2 * Theme.scale)
        actionMargin: Math.round(6 * Theme.scale)
        title: entry.modelData.name && entry.modelData.name.length > 0 ? entry.modelData.name : entry.modelData.deviceName
        onClicked: entry.modelData.connected = !entry.modelData.connected

        leading: Image {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(20 * Theme.scale)
          height: width
          sourceSize: Qt.size(width, height)
          source: Quickshell.iconPath(entry.modelData.icon, "bluetooth")
        }

        Spinner {
          anchors.verticalCenter: parent.verticalCenter
          visible: entry.connecting
          running: visible
          color: Theme.primary
        }

        IconButton {
          size: Math.round(28 * Theme.scale)
          name: "trash"
          iconColor: Theme.overlay
          hoverColor: Theme.surfaceHigher
          onClicked: root.remove(entry.modelData)
        }

        IconButton {
          size: Math.round(28 * Theme.scale)
          name: entry.expanded ? "chevron-up" : "chevron-down"
          iconColor: Theme.overlay
          onClicked: root.expandedAddress = entry.expanded ? "" : entry.modelData.address
        }
      }

      Column {
        id: expandedColumn

        visible: entry.expanded
        x: Math.round(14 * Theme.scale)
        y: rowRect.height + Math.round(6 * Theme.scale)
        width: parent.width - Math.round(28 * Theme.scale)
        spacing: Math.round(6 * Theme.scale)

        Item {
          width: parent.width
          height: Math.round(24 * Theme.scale)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: trustSwitch.left
            anchors.rightMargin: Math.round(8 * Theme.scale)
            text: "Auto-reconnect"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
          }

          Switch {
            id: trustSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: entry.modelData.trusted
            onToggled: entry.modelData.trusted = !entry.modelData.trusted
          }
        }

        Item {
          width: parent.width
          height: Math.round(24 * Theme.scale)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Address"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: entry.modelData.address
            color: Theme.overlay
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
          }
        }
      }
    }
  }
}
