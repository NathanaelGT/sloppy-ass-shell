import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "bluetooth"

  property string expanded: ""
  property string confirmRemove: ""
  property string activating: ""
  property double lastRefresh: 0
  property bool connectedExpanded: true
  property bool pairedExpanded: true
  property bool availableExpanded: true

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool enabled: root.adapter ? root.adapter.enabled : false
  readonly property bool scanning: scanProc.running

  readonly property var allDevices: {
    if (!root.adapter || !root.adapter.devices) {
      return []
    }
    const list = root.adapter.devices.values ? root.adapter.devices.values : root.adapter.devices
    const out = []
    for (let i = 0; i < list.length; i++) {
      out.push(list[i])
    }
    return out
  }

  readonly property var connectedDevices: root.matchingDevices(d => d.connected)
  readonly property var pairedDevices: root.matchingDevices(d => !d.connected && (d.paired || d.bonded))
  readonly property var availableDevices: root.matchingDevices(d => !d.connected && !d.paired && !d.bonded)

  readonly property var rows: {
    const out = []
    const groups = [
      {
        section: "connected",
        text: "Connected",
        devices: root.connectedDevices,
        active: true
      },
      {
        section: "paired",
        text: "Paired",
        devices: root.pairedDevices,
        active: false
      },
      {
        section: "available",
        text: "Available",
        devices: root.availableDevices,
        active: false
      }
    ]
    for (let g = 0; g < groups.length; g++) {
      const group = groups[g]
      if (group.devices.length === 0) {
        continue
      }
      out.push({
        kind: "label",
        section: group.section,
        text: group.text
      })
      for (let i = 0; i < group.devices.length; i++) {
        out.push({
          kind: "device",
          section: group.section,
          itemKey: group.devices[i].address,
          active: group.active
        })
      }
    }
    return out
  }

  function matchingDevices(predicate) {
    const out = []
    for (let i = 0; i < root.allDevices.length; i++) {
      if (predicate(root.allDevices[i])) {
        out.push(root.allDevices[i])
      }
    }
    out.sort((a, b) => root.nameOf(a).localeCompare(root.nameOf(b)))
    return out
  }

  function nameOf(device) {
    if (device.name && device.name.length > 0) {
      return device.name
    }
    return device.deviceName && device.deviceName.length > 0 ? device.deviceName : device.address
  }

  function findDevice(address) {
    for (let i = 0; i < root.allDevices.length; i++) {
      if (root.allDevices[i].address === address) {
        return root.allDevices[i]
      }
    }
    return null
  }

  function glyphFor(device) {
    const icon = device.icon ? device.icon : ""
    if (icon.indexOf("audio") === 0) {
      return "headphones"
    }
    if (icon.indexOf("keyboard") >= 0) {
      return "keyboard"
    }
    if (icon.indexOf("mouse") >= 0) {
      return "devices"
    }
    if (icon.indexOf("input") === 0) {
      return "devices"
    }
    if (icon.indexOf("computer") === 0) {
      return "device-laptop"
    }
    if (icon.indexOf("phone") === 0) {
      return "devices"
    }
    return "bluetooth"
  }

  function batteryPct(device) {
    return Math.round((device.battery ? device.battery : 0) * 100)
  }

  function batteryGlyph(device) {
    const pct = root.batteryPct(device)
    if (pct >= 80) {
      return "battery-4"
    }
    if (pct >= 55) {
      return "battery-3"
    }
    if (pct >= 30) {
      return "battery-2"
    }
    if (pct >= 10) {
      return "battery-1"
    }
    return "battery"
  }

  function busy(device) {
    if (!device) {
      return false
    }
    if (device.pairing) {
      return true
    }
    return device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting
  }

  function rescan() {
    if (!root.adapter || scanProc.running) {
      return
    }
    root.lastRefresh = Date.now()
    scanProc.running = true
  }

  function maybeRescan() {
    if (root.scanning || Date.now() - root.lastRefresh <= 5000) {
      return
    }
    root.rescan()
  }

  function activate(device) {
    if (!device) {
      return
    }
    if (!device.paired && !device.bonded) {
      if (device.pairing) {
        device.cancelPair()
      } else {
        device.pair()
      }
      return
    }
    root.confirmRemove = ""
    root.expanded = root.expanded === device.address ? "" : device.address
  }

  function requestRemove(device) {
    if (!device) {
      return
    }
    root.expanded = ""
    root.confirmRemove = root.confirmRemove === device.address ? "" : device.address
  }

  function toggleSection(section) {
    if (section === "connected") {
      root.connectedExpanded = !root.connectedExpanded
    } else if (section === "paired") {
      root.pairedExpanded = !root.pairedExpanded
    } else if (section === "available") {
      root.availableExpanded = !root.availableExpanded
    }
    root.expanded = ""
    root.confirmRemove = ""
  }

  function toggleTrusted(device) {
    if (!device) {
      return false
    }
    device.trusted = !device.trusted
    return true
  }

  function toggleConnected(device) {
    if (!device) {
      return false
    }
    root.activating = device.address
    activatingTimer.restart()
    if (device.connected) {
      device.disconnect()
    } else {
      device.connect()
    }
    return true
  }

  function testBluetoothState() {
    const names = list => list.map(d => root.nameOf(d))
    const trusted = {}
    const battery = {}
    for (let i = 0; i < root.allDevices.length; i++) {
      const device = root.allDevices[i]
      trusted[root.nameOf(device)] = device.trusted
      battery[root.nameOf(device)] = device.batteryAvailable ? root.batteryPct(device) : -1
    }
    return {
      expanded: root.expanded,
      confirm: root.confirmRemove,
      activating: root.activating,
      scanning: root.scanning,
      lastRefresh: root.lastRefresh,
      connectedExpanded: root.connectedExpanded,
      pairedExpanded: root.pairedExpanded,
      availableExpanded: root.availableExpanded,
      connected: names(root.connectedDevices),
      paired: names(root.pairedDevices),
      available: names(root.availableDevices),
      trusted: trusted,
      battery: battery
    }
  }

  function testToggleSection(section) {
    if (section !== "connected" && section !== "paired" && section !== "available") {
      return false
    }
    root.toggleSection(section)
    return true
  }

  function testSetSection(section, state) {
    const value = state === true
    if (section === "connected") {
      root.connectedExpanded = value
    } else if (section === "paired") {
      root.pairedExpanded = value
    } else if (section === "available") {
      root.availableExpanded = value
    } else {
      return false
    }
    root.expanded = ""
    root.confirmRemove = ""
    return true
  }

  function testToggleExpanded(address) {
    const device = root.findDevice(address)
    if (!device) {
      return false
    }
    root.activate(device)
    return true
  }

  function testAskRemove(address) {
    const device = root.findDevice(address)
    if (!device) {
      return false
    }
    root.requestRemove(device)
    return true
  }

  function testConfirmRemove() {
    if (!root.confirmRemove) {
      return false
    }
    const device = root.findDevice(root.confirmRemove)
    root.confirmRemove = ""
    if (!device) {
      return false
    }
    device.forget()
    return true
  }

  function testCancelRemove() {
    if (!root.confirmRemove) {
      return false
    }
    root.confirmRemove = ""
    return true
  }

  function testToggleTrusted(address) {
    return root.toggleTrusted(root.findDevice(address))
  }

  function testToggleConnected(address) {
    return root.toggleConnected(root.findDevice(address))
  }

  onOpened: {
    root.expanded = ""
    root.confirmRemove = ""
    root.activating = ""
    root.maybeRescan()
  }

  onOpenChanged: if (!root.open) {
    scanProc.running = false
  }

  Process {
    id: scanProc

    running: false
    command: ["bash", "-lc", "exec bluetoothctl --timeout 3600 scan on >/dev/null 2>&1"]
  }

  Timer {
    id: activatingTimer

    interval: 30000
    onTriggered: root.activating = ""
  }

  PanelHeader {
    title: "Bluetooth"

    IconButton {
      name: "refresh"
      visible: root.enabled
      enabled: !root.scanning
      iconColor: root.scanning ? Theme.overlay : Theme.text
      spinning: root.scanning
      onClicked: root.rescan()
    }

    Switch {
      anchors.verticalCenter: parent.verticalCenter
      checked: root.enabled
      onToggled: if (root.adapter) {
        root.adapter.enabled = !root.adapter.enabled
      }
    }
  }

  Rectangle {
    visible: root.enabled
    width: parent.width
    height: visible ? Math.round(44 * Theme.scale) : 0
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

  PlaceholderCard {
    shown: !root.enabled || root.rows.length === 0
    instant: !root.enabled
    icon: !root.enabled ? "bluetooth-off" : "bluetooth"
    text: !root.enabled ? "Bluetooth is off" : "Scanning"
    rolling: root.enabled && root.rows.length === 0
  }

  SectionList {
    id: list

    visible: root.enabled && count > 0
    height: visible ? contentHeight : 0
    entries: root.rows
    sections: ({
        connected: root.connectedExpanded,
        paired: root.pairedExpanded,
        available: root.availableExpanded
      })
    onSectionToggled: root.toggleSection(section)

    delegate: Item {
      id: entry

      objectName: "btRow"

      required property string key
      required property string kind
      required property string section
      required property string label
      required property string itemKey
      required property bool active

      readonly property var device: entry.isLabel ? null : root.findDevice(entry.itemKey)
      readonly property bool isLabel: entry.kind === "label"
      readonly property bool isConnected: entry.device ? entry.device.connected : entry.active
      readonly property bool isPaired: entry.device ? (entry.device.paired || entry.device.bonded) : true
      readonly property bool pairing: entry.device ? entry.device.pairing : false
      readonly property bool changing: entry.device ? root.busy(entry.device) && !entry.device.pairing : false
      readonly property bool busy: entry.device ? root.busy(entry.device) || (root.activating !== "" && root.activating === entry.itemKey) : false
      readonly property bool confirmOpen: !entry.isLabel && root.confirmRemove === entry.itemKey
      readonly property bool actionsOpen: !entry.isLabel && entry.isPaired && !entry.confirmOpen && root.expanded === entry.itemKey
      readonly property bool highlighted: entry.isConnected || headerMouse.containsMouse || cardHover.containsMouse || confirmCancelBtn.hovered || confirmCheckBtn.hovered || trashActionBtn.hovered || toggleActionBtn.hovered || trustHover.containsMouse || cancelPairBtn.hovered
      readonly property bool shown: entry.isLabel ? true : list.isExpanded(entry.section)
      readonly property int extraHeight: entry.confirmOpen || entry.actionsOpen ? Math.round(34 * Theme.scale) : 0
      readonly property color cardColor: entry.highlighted ? Theme.surfaceHigh : Theme.surface
      readonly property color hoverSurface: Theme.surfaceHigher
      readonly property color strongText: entry.isConnected ? Theme.primary : Theme.text
      readonly property color mutedText: Theme.subtext
      readonly property color hoverText: Theme.text

      onChangingChanged: if (entry.changing && !entry.isLabel && root.activating === entry.itemKey) {
        root.activating = ""
      }

      width: list.width
      height: entry.shown ? (entry.isLabel ? Math.round(20 * Theme.scale) : Math.round(44 * Theme.scale) + entry.extraHeight) : 0
      opacity: entry.shown ? 1 : 0
      clip: true

      Behavior on height {
        NumberAnimation {
          duration: 220
          easing.type: Easing.OutCubic
        }
      }
      Behavior on opacity {
        NumberAnimation {
          duration: 160
          easing.type: Easing.OutCubic
        }
      }

      SectionHeaderRow {
        visible: entry.isLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        label: entry.label
        section: entry.section
        expanded: list.isExpanded(entry.section)
        onToggleRequested: list.toggleSection(entry.section)
      }

      Rectangle {
        visible: !entry.isLabel
        width: parent.width
        height: parent.height
        radius: Theme.rowRadius
        color: entry.cardColor
        antialiasing: true
        clip: true

        Behavior on color {
          ColorAnimation {
            duration: 220
            easing.type: Easing.OutCubic
          }
        }

        MouseArea {
          id: cardHover

          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
        }

        MouseArea {
          id: headerMouse

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Math.round(44 * Theme.scale)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (entry.device) {
            root.activate(entry.device)
          }
        }

        Item {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Math.round(44 * Theme.scale)

          Item {
            id: leadingHost

            anchors.left: parent.left
            anchors.leftMargin: Math.round(12 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: children.length > 0 ? children[0].width : 0
            height: children.length > 0 ? children[0].height : 0

            Icon {
              anchors.verticalCenter: parent.verticalCenter
              name: entry.device ? root.glyphFor(entry.device) : "bluetooth"
              color: entry.strongText
              font.pixelSize: Theme.iconSizeLarge

              Behavior on color {
                ColorAnimation {
                  duration: 220
                  easing.type: Easing.OutCubic
                }
              }
            }
          }

          Text {
            anchors.left: leadingHost.right
            anchors.leftMargin: Math.round(10 * Theme.scale)
            anchors.right: actionsRow.left
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: entry.device ? root.nameOf(entry.device) : entry.itemKey
            color: entry.strongText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: entry.isConnected
            elide: Text.ElideRight

            Behavior on color {
              ColorAnimation {
                duration: 220
                easing.type: Easing.OutCubic
              }
            }
          }

          Row {
            id: actionsRow

            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(6 * Theme.scale)
            z: 1

            Icon {
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.device ? entry.device.batteryAvailable : false
              name: entry.device ? root.batteryGlyph(entry.device) : ""
              color: entry.mutedText
              font.pixelSize: Theme.fontSize
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: entry.device && entry.device.batteryAvailable ? root.batteryPct(entry.device) + "%" : ""
              color: entry.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
            }

            Spinner {
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.busy && !entry.actionsOpen
              running: visible
              color: entry.strongText
            }

            IconButton {
              id: cancelPairBtn

              visible: entry.pairing
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(24 * Theme.scale)
              glyphSize: Math.round(14 * Theme.scale)
              name: "x"
              iconColor: cancelPairBtn.hovered ? Theme.text : Theme.overlay
              hoverColor: Theme.surfaceHigher
              onClicked: if (entry.device) {
                entry.device.cancelPair()
              }
            }
          }
        }

        Item {
          visible: entry.confirmOpen
          width: parent.width
          anchors.top: parent.top
          anchors.topMargin: Math.round(44 * Theme.scale)
          height: visible ? Math.round(34 * Theme.scale) : 0
          clip: true

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Math.round(4 * Theme.scale)
            anchors.leftMargin: Math.round(12 * Theme.scale)
            anchors.rightMargin: Math.round(6 * Theme.scale)
            height: Math.round(20 * Theme.scale)
            spacing: Math.round(4 * Theme.scale)

            Text {
              width: parent.width - Math.round(48 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              text: "Remove " + (entry.device ? root.nameOf(entry.device) : entry.itemKey) + "?"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
            }

            IconButton {
              id: confirmCancelBtn

              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: "x"
              iconColor: confirmCancelBtn.hovered ? Theme.text : Theme.overlay
              hoverColor: Theme.surfaceHigher
              onClicked: root.confirmRemove = ""
            }

            IconButton {
              id: confirmCheckBtn

              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: "check"
              iconColor: Theme.red
              hoverColor: Theme.surfaceHigher
              onClicked: {
                const device = root.findDevice(root.confirmRemove)
                root.confirmRemove = ""
                if (device) {
                  device.forget()
                }
              }
            }
          }
        }

        Item {
          visible: entry.actionsOpen
          width: parent.width
          anchors.top: parent.top
          anchors.topMargin: Math.round(44 * Theme.scale)
          height: visible ? Math.round(34 * Theme.scale) : 0
          clip: true

          Item {
            x: Math.round(12 * Theme.scale)
            width: parent.width - Math.round(12 * Theme.scale) - Math.round(6 * Theme.scale)
            height: Math.round(20 * Theme.scale)
            y: Math.round(4 * Theme.scale)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: entry.device ? entry.device.address : ""
              color: entry.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
            }

            IconButton {
              id: toggleActionBtn

              visible: !entry.busy
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              name: entry.isConnected ? "plug" : "plug-connected"
              iconColor: toggleActionBtn.hovered ? entry.hoverText : Theme.overlay
              hoverColor: entry.hoverSurface
              onClicked: root.toggleConnected(entry.device)
            }

            Spinner {
              anchors.right: parent.right
              anchors.rightMargin: Math.round(2 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.busy
              running: visible
              color: Theme.primary
            }

            IconButton {
              id: trashActionBtn

              anchors.right: toggleActionBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              name: "trash"
              iconColor: trashActionBtn.hovered ? entry.hoverText : Theme.overlay
              hoverColor: entry.hoverSurface
              onClicked: root.requestRemove(entry.device)
            }

            Rectangle {
              id: trustBtn

              anchors.right: trashActionBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              width: trustLabel.implicitWidth + Math.round(16 * Theme.scale)
              height: Math.round(20 * Theme.scale)
              radius: height / 2
              color: trustHover.containsMouse ? entry.hoverSurface : "transparent"
              antialiasing: true

              Text {
                id: trustLabel

                anchors.centerIn: parent
                text: "TRUSTED"
                color: entry.device && entry.device.trusted ? Theme.primary : Theme.overlay
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: entry.device ? entry.device.trusted : false

                Behavior on color {
                  ColorAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                  }
                }
              }

              MouseArea {
                id: trustHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTrusted(entry.device)
              }
            }
          }
        }
      }
    }
  }
}
