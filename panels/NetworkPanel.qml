import QtQuick
import Quickshell.Networking
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "network"

  property var pending: null
  property string password: ""

  readonly property bool enabled: Networking.wifiEnabled

  readonly property var device: {
    const list = Networking.devices ? Networking.devices.values : [];
    for (let i = 0; i < list.length; i++) if (list[i].type === DeviceType.Wifi) return list[i];
    return null;
  }

  readonly property var allNetworks: {
    if (!device || !device.networks) return [];
    const list = device.networks.values ? device.networks.values : device.networks;
    const out = [];
    for (let i = 0; i < list.length; i++) out.push(list[i]);
    return out;
  }

  readonly property var connectedNetwork: {
    for (let i = 0; i < allNetworks.length; i++) if (allNetworks[i].connected) return allNetworks[i];
    return null;
  }

  readonly property var savedNetworks: {
    const out = [];
    for (let i = 0; i < allNetworks.length; i++) {
      const n = allNetworks[i];
      if (n.known && !n.connected) out.push(n);
    }
    out.sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0));
    return out;
  }

  readonly property var availableNetworks: {
    const out = [];
    for (let i = 0; i < allNetworks.length; i++) {
      const n = allNetworks[i];
      if (!n.known && !n.connected) out.push(n);
    }
    out.sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0));
    return out;
  }

  readonly property var rows: {
    const out = [];
    if (connectedNetwork) out.push({ kind: "connected", net: connectedNetwork });
    if (savedNetworks.length > 0) {
      out.push({ kind: "label", text: "Saved" });
      for (let i = 0; i < savedNetworks.length; i++) out.push({ kind: "net", net: savedNetworks[i] });
    }
    if (availableNetworks.length > 0) {
      out.push({ kind: "label", text: "Available" });
      for (let i = 0; i < availableNetworks.length; i++) out.push({ kind: "net", net: availableNetworks[i] });
    }
    return out;
  }

  function signalPct(network) {
    const s = network && network.signalStrength ? network.signalStrength : 0;
    return Math.round(s > 1 ? s : s * 100);
  }

  function glyphFor(network) {
    const pct = signalPct(network);
    if (pct > 66) return "wifi-2";
    if (pct > 33) return "wifi-1";
    return "wifi-0";
  }

  function secured(network) {
    return network.security !== WifiSecurityType.Open;
  }

  function rescan() {
    if (!device) return;
    device.scannerEnabled = false;
    device.scannerEnabled = true;
  }

  function activate(network) {
    if (network.connected) {
      network.disconnect();
      return;
    }
    if (secured(network) && !network.known) {
      root.password = "";
      root.pending = network;
      return;
    }
    network.connect();
  }

  onOpened: {
    rescan();
    pending = null;
  }

  PanelHeader {
    title: "Wi-Fi"

    IconButton {
      name: "refresh"
      onClicked: root.rescan()
    }

    Switch {
      checked: root.enabled
      onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }
  }

  Column {
    visible: root.pending !== null
    width: parent.width
    spacing: Math.round(6 * Theme.scale)

    SectionLabel {
      label: root.pending ? "Password for " + root.pending.name : ""
    }

    Rectangle {
      width: parent.width
      height: Math.round(40 * Theme.scale)
      radius: Theme.rowRadius
      color: Theme.surface
      antialiasing: true

      Row {
        anchors.fill: parent
        anchors.leftMargin: Math.round(12 * Theme.scale)
        anchors.rightMargin: Math.round(6 * Theme.scale)
        spacing: Math.round(8 * Theme.scale)

        TextInput {
          id: passwordField

          width: parent.width - Math.round(80 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.text
          echoMode: TextInput.Password
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          clip: true
          onAccepted: {
            if (root.pending) root.pending.connectWithPsk(root.password);
            root.pending = null;
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: passwordField.text.length === 0
            text: "Password"
            color: Theme.overlay
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
          }
        }

        IconButton {
          size: Math.round(28 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          name: "check"
          iconColor: Theme.primary
          onClicked: {
            if (root.pending) root.pending.connectWithPsk(root.password);
            root.pending = null;
          }
        }
      }

      onVisibleChanged: {
        if (visible) passwordField.forceActiveFocus();
      }
    }
  }

  Text {
    visible: !root.enabled
    width: parent.width
    text: "Wi-Fi is off"
    color: Theme.overlay
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignHCenter
  }

  ListView {
    id: list

    visible: root.enabled
    width: parent.width
    height: visible ? Math.min(contentHeight, Math.round(360 * Theme.scale)) : 0
    implicitHeight: height
    clip: true
    spacing: Math.round(4 * Theme.scale)
    model: root.rows

    delegate: Item {
      id: entry

      required property var modelData

      readonly property var net: modelData.net
      readonly property bool isConnected: net ? net.connected : false

      width: list.width
      height: modelData.kind === "label" ? Math.round(24 * Theme.scale) : Math.round(44 * Theme.scale)

      SectionLabel {
        visible: entry.modelData.kind === "label"
        anchors.left: parent.left
        anchors.leftMargin: Math.round(4 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        label: entry.modelData.kind === "label" ? entry.modelData.text : ""
      }

      SelectableRow {
        visible: entry.modelData.kind !== "label"
        title: entry.net ? entry.net.name : ""
        active: entry.isConnected
        boldTitle: entry.isConnected
        onClicked: if (entry.net) root.activate(entry.net)

        leading: Icon {
          anchors.verticalCenter: parent.verticalCenter
          name: entry.net ? root.glyphFor(entry.net) : "wifi"
          color: entry.isConnected ? Theme.primary : Theme.text
          font.pixelSize: Theme.iconSizeLarge
        }

        Icon {
          anchors.verticalCenter: parent.verticalCenter
          visible: entry.net ? root.secured(entry.net) : false
          name: "lock"
          color: Theme.overlay
          font.pixelSize: Theme.fontSize
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: entry.net ? root.signalPct(entry.net) + "%" : ""
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }

        Spinner {
          anchors.verticalCenter: parent.verticalCenter
          visible: entry.net ? entry.net.stateChanging : false
          running: visible
          color: Theme.primary
        }

        IconButton {
          visible: entry.net ? entry.net.known && !entry.isConnected : false
          size: Math.round(28 * Theme.scale)
          name: "trash"
          iconColor: Theme.overlay
          hoverColor: Theme.surfaceHigher
          onClicked: if (entry.net) entry.net.forget()
        }

        Icon {
          anchors.verticalCenter: parent.verticalCenter
          visible: entry.isConnected
          name: "check"
          color: Theme.primary
          font.pixelSize: Theme.iconSize
        }
      }
    }
  }

  Text {
    visible: root.enabled && root.rows.length === 0
    width: parent.width
    text: "Scanning…"
    color: Theme.overlay
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignHCenter
  }
}
