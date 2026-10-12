import QtQuick
import Quickshell.Networking
import Quickshell.Io
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "network"

  property string pending: ""
  property bool showPassword: false
  property string confirmForget: ""
  property string expanded: ""
  property string activating: ""
  property bool scanning: false
  property double lastRefresh: 0
  property var autoConnect: ({})
  property var modifyQueue: null
  property bool connectedExpanded: true
  property bool savedExpanded: true
  property bool availableExpanded: true

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
    if (connectedNetwork) {
      out.push({ kind: "label", section: "connected", text: "Connected" });
      out.push({ kind: "connected", section: "connected", net: connectedNetwork });
    }
    if (savedNetworks.length > 0) {
      out.push({ kind: "label", section: "saved", text: "Saved" });
      for (let i = 0; i < savedNetworks.length; i++) out.push({ kind: "net", section: "saved", net: savedNetworks[i] });
    }
    if (availableNetworks.length > 0) {
      out.push({ kind: "label", section: "available", text: "Available" });
      for (let i = 0; i < availableNetworks.length; i++) out.push({ kind: "net", section: "available", net: availableNetworks[i] });
    }
    return out;
  }

  function rowKey(entry) {
    if (entry.kind === "label") return "label:" + entry.section;
    return "net:" + entry.net.name;
  }

  ListModel {
    id: wifiModel
  }

  function syncRows() {
    const rows = root.rows;
    const wanted = {};
    for (let j = 0; j < rows.length; j++) {
      const entry = rows[j];
      let key = root.rowKey(entry);
      if (entry.kind !== "label") {
        let n = 0;
        while (wanted[key] !== undefined) {
          n += 1;
          key = root.rowKey(entry) + "#" + n;
        }
      }
      wanted[key] = j;
    }
    for (let i = wifiModel.count - 1; i >= 0; i--) if (wanted[wifiModel.get(i).key] === undefined) wifiModel.remove(i);
    for (let j = 0; j < rows.length; j++) {
      const entry = rows[j];
      const isLabel = entry.kind === "label";
      const label = isLabel ? entry.text : "";
      const netName = isLabel ? "" : entry.net.name;
      const connected = isLabel ? false : !!entry.net.connected;
      let key = root.rowKey(entry);
      if (!isLabel) {
        let n = 0;
        while (wanted[key] !== undefined && wanted[key] !== j) {
          n += 1;
          key = root.rowKey(entry) + "#" + n;
        }
      }
      wanted[key] = j;
      let at = -1;
      for (let i = 0; i < wifiModel.count; i++) if (wifiModel.get(i).key === key) {
        at = i;
        break;
      }
      if (at < 0) {
        wifiModel.insert(j, { key: key, kind: entry.kind, section: entry.section, label: label, netName: netName, connected: connected });
      } else {
        if (at !== j) wifiModel.move(at, j, 1);
        if (wifiModel.get(j).kind !== entry.kind) wifiModel.setProperty(j, "kind", entry.kind);
        if (wifiModel.get(j).section !== entry.section) wifiModel.setProperty(j, "section", entry.section);
        if (wifiModel.get(j).label !== label) wifiModel.setProperty(j, "label", label);
        if (wifiModel.get(j).netName !== netName) wifiModel.setProperty(j, "netName", netName);
        if (wifiModel.get(j).connected !== connected) wifiModel.setProperty(j, "connected", connected);
      }
    }
  }

  onRowsChanged: root.syncRows()

  onEnabledChanged: {
    if (!root.enabled) return;
    root.maybeRescan();
  }

  onCardHoveredChanged: {
    if (cardHovered) root.maybeRescan();
  }

  function sectionExpanded(section) {
    if (section === "connected") return root.connectedExpanded;
    if (section === "saved") return root.savedExpanded;
    return root.availableExpanded;
  }

  function toggleSection(section) {
    if (section === "connected") root.connectedExpanded = !root.connectedExpanded;
    else if (section === "saved") root.savedExpanded = !root.savedExpanded;
    else if (section === "available") root.availableExpanded = !root.availableExpanded;
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
    if (!device || scanProc.running) return;
    root.scanning = true;
    scanProc.command = ["nmcli", "device", "wifi", "list", "ifname", device.name, "--rescan", "yes"];
    scanProc.running = true;
  }

  function lastRefreshAge() {
    return Date.now() - root.lastRefresh;
  }

  function maybeRescan() {
    if (root.scanning || root.lastRefreshAge() <= 5000) return;
    root.rescan();
  }

  function activate(network) {
    if (!network) return;
    if (secured(network) && !network.known) {
      if (root.pending === network.name) root.pending = "";
      else {
        root.pending = network.name;
        root.showPassword = false;
      }
      root.confirmForget = "";
      root.expanded = "";
      return;
    }
    root.pending = "";
    root.confirmForget = "";
    root.expanded = root.expanded === network.name ? "" : network.name;
  }

  function requestForget(network) {
    if (!network) return;
    root.pending = "";
    root.confirmForget = root.confirmForget === network.name ? "" : network.name;
  }

  function toggleExpanded(network) {
    if (!network) return false;
    root.pending = "";
    root.confirmForget = "";
    root.expanded = root.expanded === network.name ? "" : network.name;
    return true;
  }

  function autoEnabled(name) {
    return root.autoConnect[name] !== false;
  }

  function queryAutoConnect() {
    if (queryProc.running) return;
    queryProc.command = ["nmcli", "-t", "-f", "NAME,AUTOCONNECT", "connection", "show"];
    queryProc.running = true;
  }

  function setAutoConnect(name, value) {
    const next = {};
    for (const k in root.autoConnect) next[k] = root.autoConnect[k];
    next[name] = value;
    root.autoConnect = next;
    root.modifyQueue = [name, value ? "yes" : "no"];
    root.pumpModify();
  }

  function pumpModify() {
    if (modifyProc.running || !root.modifyQueue) return;
    const job = root.modifyQueue;
    root.modifyQueue = null;
    modifyProc.command = ["nmcli", "connection", "modify", job[0], "connection.autoconnect", job[1]];
    modifyProc.running = true;
  }

  Process {
    id: scanProc

    running: false
    onExited: {
      root.scanning = false;
      root.lastRefresh = Date.now();
    }
  }

  Process {
    id: queryProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const next = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
          const m = lines[i].match(/^(.*):(yes|no)$/);
          if (m) next[m[1].replace(/\\:/g, ":")] = m[2] === "yes";
        }
        root.autoConnect = next;
      }
    }
  }

  Process {
    id: modifyProc

    running: false
    onExited: {
      root.pumpModify();
      root.queryAutoConnect();
    }
  }

  Timer {
    id: activatingTimer

    interval: 30000
    onTriggered: root.activating = ""
  }

  function rowDelegates() {
    const out = [];
    const kids = list.contentItem.children;
    for (let i = 0; i < kids.length; i++) if (kids[i] && kids[i].objectName === "wifiRow") out.push(kids[i]);
    return out;
  }

  function editorForName(name) {
    if (!name) return null;
    const rows = root.rowDelegates();
    for (let i = 0; i < rows.length; i++) if (rows[i].netName === name) return rows[i].passwordEditor;
    return null;
  }

  function findNetwork(name) {
    for (let i = 0; i < allNetworks.length; i++) if (allNetworks[i].name === name) return allNetworks[i];
    return null;
  }

  function testBeginPassword(name) {
    const network = root.findNetwork(name);
    if (!network || !root.secured(network) || network.known) return false;
    root.pending = name;
    root.showPassword = false;
    root.confirmForget = "";
    root.expanded = "";
    return true;
  }

  function testSetPassword(text) {
    const editor = root.editorForName(root.pending);
    if (!editor) return false;
    editor.text = text;
    return true;
  }

  function testPasswordEcho() {
    const editor = root.editorForName(root.pending);
    if (!editor) return "";
    return editor.echoMode === TextInput.Password ? "hidden" : "shown";
  }

  function testToggleShowPassword() {
    root.showPassword = !root.showPassword;
    return root.showPassword;
  }

  function testPasswordRect() {
    const editor = root.editorForName(root.pending);
    if (!editor) return null;
    const point = editor.mapToItem(null, 0, 0);
    if (!point) return null;
    return { x: point.x, y: point.y, width: editor.width, height: editor.height, echo: root.testPasswordEcho() };
  }

  function testSubmitPassword() {
    const editor = root.editorForName(root.pending);
    if (!editor || !root.pending) return false;
    const network = root.findNetwork(root.pending);
    if (!network) return false;
    network.connectWithPsk(editor.text);
    root.pending = "";
    return true;
  }

  function testAskForget(name) {
    const network = root.findNetwork(name);
    if (!network) return false;
    root.requestForget(network);
    return true;
  }

  function testConfirmForget() {
    if (!root.confirmForget) return false;
    const network = root.findNetwork(root.confirmForget);
    if (!network) {
      root.confirmForget = "";
      return false;
    }
    network.forget();
    root.confirmForget = "";
    return true;
  }

  function testCancelForget() {
    if (!root.confirmForget) return false;
    root.confirmForget = "";
    return true;
  }

  function testToggleExpanded(name) {
    const network = root.findNetwork(name);
    if (!network) return false;
    return root.toggleExpanded(network);
  }

  function testToggleAutoConnect(name) {
    const network = root.findNetwork(name);
    if (!network || !network.known) return false;
    root.setAutoConnect(name, !root.autoEnabled(name));
    return true;
  }

  function testSetSection(section, state) {
    const value = state === true;
    if (section === "connected") root.connectedExpanded = value;
    else if (section === "saved") root.savedExpanded = value;
    else if (section === "available") root.availableExpanded = value;
    else return false;
    return true;
  }

  function testWifiState() {
    return {
      pending: root.pending,
      showPassword: root.showPassword,
      confirm: root.confirmForget,
      expanded: root.expanded,
      activating: root.activating,
      scanning: root.scanning,
      lastRefresh: root.lastRefresh,
      auto: root.autoConnect,
      connectedExpanded: root.connectedExpanded,
      savedExpanded: root.savedExpanded,
      availableExpanded: root.availableExpanded,
      connected: root.connectedNetwork ? root.connectedNetwork.name : "",
      saved: root.savedNetworks.map((n) => n.name),
      available: root.availableNetworks.map((n) => n.name)
    };
  }

  onOpened: {
    root.maybeRescan();
    pending = "";
    confirmForget = "";
    expanded = "";
    activating = "";
    showPassword = false;
    queryAutoConnect();
  }

  PanelHeader {
    title: "Wi-Fi"

    IconButton {
      name: "refresh"
      visible: root.enabled && root.rows.length > 0
      enabled: !root.scanning
      iconColor: root.scanning ? Theme.overlay : Theme.text
      spinning: root.scanning
      onClicked: root.rescan()
    }

    Switch {
      anchors.verticalCenter: parent.verticalCenter
      checked: root.enabled
      onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }
  }

  PlaceholderCard {
    shown: !root.enabled || (root.enabled && root.rows.length === 0)
    instant: !root.enabled
    icon: !root.enabled ? "wifi-off" : "wifi"
    text: !root.enabled ? "Wi-Fi is off" : "Scanning"
    rolling: root.enabled && root.rows.length === 0
  }

  ListView {
    id: list

    visible: root.enabled && wifiModel.count > 0
    width: parent.width
    height: visible ? contentHeight : 0
    implicitHeight: height
    interactive: false
    focus: false
    clip: true
    spacing: Theme.gap
    model: wifiModel

    delegate: Item {
      id: entry

      objectName: "wifiRow"

      required property string key
      required property string kind
      required property string section
      required property string label
      required property string netName
      required property bool connected

      readonly property var net: entry.isLabel ? null : root.findNetwork(entry.netName)
      readonly property bool isLabel: entry.kind === "label"
      readonly property bool isConnected: entry.net ? entry.net.connected : entry.connected
      readonly property bool pwOpen: !entry.isLabel && root.pending !== "" && root.pending === entry.netName
      readonly property bool confirmOpen: !entry.isLabel && root.confirmForget !== "" && root.confirmForget === entry.netName
      readonly property bool actionsOpen: !entry.isLabel && root.expanded !== "" && root.expanded === entry.netName && !entry.pwOpen && !entry.confirmOpen
      readonly property bool changing: entry.net ? entry.net.stateChanging : false
      readonly property bool busy: entry.changing || (!entry.isLabel && root.activating !== "" && root.activating === entry.netName)
      onChangingChanged: if (entry.changing && !entry.isLabel && root.activating === entry.netName) root.activating = ""
      readonly property var passwordEditor: pwField
      readonly property bool highlighted: entry.isConnected || headerMouse.containsMouse || cardHover.containsMouse || pwHover.containsMouse || eyeBtn.hovered || passCheckBtn.hovered || forgetCancelBtn.hovered || forgetCheckBtn.hovered || trashActionBtn.hovered || toggleActionBtn.hovered || badgeHover.containsMouse
      readonly property bool shown: entry.isLabel ? true : root.sectionExpanded(entry.section)
      readonly property int extraHeight: (entry.pwOpen || entry.confirmOpen || entry.actionsOpen) ? Math.round(34 * Theme.scale) : 0

      width: list.width
      height: entry.shown ? (entry.isLabel ? Math.round(20 * Theme.scale) : Math.round(44 * Theme.scale) + entry.extraHeight) : 0
      opacity: entry.shown ? 1 : 0
      clip: true

      Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      SectionHeader {
        visible: entry.isLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        label: entry.label

        IconButton {
          size: Math.round(20 * Theme.scale)
          name: root.sectionExpanded(entry.section) ? "chevron-up" : "chevron-down"
          iconColor: Theme.overlay
          onClicked: root.toggleSection(entry.section)
        }
      }

      Rectangle {
        visible: !entry.isLabel
        width: parent.width
        height: parent.height
        radius: Theme.rowRadius
        color: entry.highlighted ? Theme.surfaceHigh : Theme.surface
        antialiasing: true
        clip: true

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
          onClicked: if (entry.net) root.activate(entry.net)
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
              name: entry.net ? root.glyphFor(entry.net) : "wifi"
              color: entry.isConnected ? Theme.primary : Theme.text
              font.pixelSize: Theme.iconSizeLarge
            }
          }

          Text {
            anchors.left: leadingHost.right
            anchors.leftMargin: Math.round(10 * Theme.scale)
            anchors.right: actionsRow.left
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: entry.net ? entry.net.name : entry.netName
            color: entry.isConnected ? Theme.primary : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: entry.isConnected
            elide: Text.ElideRight
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
              visible: entry.busy && !entry.actionsOpen
              running: visible
              color: Theme.primary
            }
          }
        }

        Item {
          visible: entry.pwOpen
          width: parent.width
          anchors.top: parent.top
          anchors.topMargin: Math.round(44 * Theme.scale)
          height: visible ? Math.round(34 * Theme.scale) : 0
          clip: true

          onVisibleChanged: if (visible) pwField.forceActiveFocus()

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Math.round(4 * Theme.scale)
            anchors.leftMargin: Math.round(12 * Theme.scale)
            anchors.rightMargin: Math.round(6 * Theme.scale)
            height: Math.round(20 * Theme.scale)
            spacing: Math.round(4 * Theme.scale)

            TextInput {
              id: pwField

              width: parent.width - Math.round(48 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.text
              echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              clip: true
              onAccepted: {
                const network = root.findNetwork(root.pending);
                if (network) network.connectWithPsk(pwField.text);
                root.pending = "";
              }

              MouseArea {
                id: pwHover

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.IBeamCursor
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pwField.text.length === 0
                text: "Password"
                color: Theme.overlay
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
              }
            }

            IconButton {
              id: eyeBtn

              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: root.showPassword ? "eye-off" : "eye"
              iconColor: eyeBtn.hovered ? Theme.text : Theme.overlay
              hoverColor: Theme.surfaceHigher
              onClicked: root.showPassword = !root.showPassword
            }

            IconButton {
              id: passCheckBtn

              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: "check"
              iconColor: Theme.primary
              hoverColor: Theme.surfaceHigher
              onClicked: {
                const network = root.findNetwork(root.pending);
                if (network) network.connectWithPsk(pwField.text);
                root.pending = "";
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
              text: "Forget " + entry.netName + "?"
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
            }

            IconButton {
              id: forgetCancelBtn

              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: "x"
              iconColor: forgetCancelBtn.hovered ? Theme.text : Theme.overlay
              hoverColor: Theme.surfaceHigher
              onClicked: root.confirmForget = ""
            }

            IconButton {
              id: forgetCheckBtn

              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: "check"
              iconColor: Theme.red
              hoverColor: Theme.surfaceHigher
              onClicked: {
                const network = root.findNetwork(root.confirmForget);
                if (network) network.forget();
                root.confirmForget = "";
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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Math.round(4 * Theme.scale)
            anchors.leftMargin: Math.round(12 * Theme.scale)
            anchors.rightMargin: Math.round(6 * Theme.scale)
            height: Math.round(20 * Theme.scale)

            IconButton {
              id: toggleActionBtn

              visible: !entry.busy
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              name: entry.isConnected ? "plug" : "plug-connected"
              iconColor: toggleActionBtn.hovered ? Theme.text : Theme.overlay
              hoverColor: Theme.surfaceHigher
              onClicked: {
                if (!entry.net) return;
                root.activating = entry.net.name;
                activatingTimer.restart();
                if (entry.isConnected) entry.net.disconnect();
                else entry.net.connect();
              }
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

              visible: entry.net ? entry.net.known : false
              anchors.right: toggleActionBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              name: "trash"
              iconColor: trashActionBtn.hovered ? Theme.text : Theme.overlay
              hoverColor: Theme.surfaceHigher
              onClicked: if (entry.net) root.requestForget(entry.net)
            }

            Rectangle {
              id: autoToggleBtn

              visible: entry.net ? entry.net.known : false
              anchors.right: trashActionBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(44 * Theme.scale)
              height: Math.round(20 * Theme.scale)
              radius: height / 2
              color: badgeHover.containsMouse ? Theme.surfaceHigher : "transparent"
              antialiasing: true

              Text {
                anchors.centerIn: parent
                text: "AUTO"
                color: root.autoEnabled(entry.netName) ? Theme.primary : Theme.overlay
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: root.autoEnabled(entry.netName)
              }

              MouseArea {
                id: badgeHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (entry.net) root.setAutoConnect(entry.netName, !root.autoEnabled(entry.netName))
              }
            }
          }
        }

      }
    }
  }
}
