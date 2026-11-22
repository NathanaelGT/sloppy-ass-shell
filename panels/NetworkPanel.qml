import QtQuick
import Quickshell
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
  property string pskAttempt: ""
  property string sharing: ""
  property bool scanning: false
  property double lastRefresh: 0
  property var autoConnect: ({})
  property var modifyQueue: []
  property var pskCache: ({})
  property var pskQueue: []
  property bool connectedExpanded: true
  property bool savedExpanded: true
  property bool availableExpanded: true
  property var sortStrength: ({})
  property double confirmArmedAt: 0
  property bool queryPending: false
  property bool scanInFlight: false
  property bool modifyInFlight: false
  property bool pskInFlight: false
  property bool scanOpen: false
  property string scanPhase: "idle"
  property string scanStatus: ""
  property string scanFrame: ""
  property string scanLastPayload: ""
  property var scanDecoded: null
  property string scanTarget: ""
  property var scanParsed: null
  property string scanResumePhase: "scanning"
  property string decodeMode: ""
  property bool joinInFlight: false
  readonly property string scanToolPath: Quickshell.configDir + "/tools/qrscan/qrscan.mjs"
  readonly property bool interacting: pending !== "" || expanded !== "" || confirmForget !== "" || sharing !== "" || activating !== ""
  readonly property bool enabled: Networking.wifiEnabled
  readonly property var device: {
    const list = Networking.devices ? Networking.devices.values : []
    for (let i = 0; i < list.length; i++) {
      if (list[i].type === DeviceType.Wifi) {
        return list[i]
      }
    }
    return null
  }
  onDeviceChanged: {
    if (root.device && root.open) {
      root.device.scannerEnabled = true
    }
  }
  readonly property var allNetworks: {
    if (!device || !device.networks) {
      return []
    }
    const list = device.networks.values ? device.networks.values : device.networks
    const out = []
    for (let i = 0; i < list.length; i++) {
      out.push(list[i])
    }
    return out
  }
  readonly property var connectedNetwork: {
    for (let i = 0; i < allNetworks.length; i++) {
      if (allNetworks[i].connected) {
        return allNetworks[i]
      }
    }
    return null
  }
  readonly property var savedNetworks: {
    const out = []
    for (let i = 0; i < allNetworks.length; i++) {
      const n = allNetworks[i]
      if (n.known && !n.connected) {
        out.push(n)
      }
    }
    out.sort((a, b) => root.sortValue(b) - root.sortValue(a))
    return out
  }
  readonly property var availableNetworks: {
    const out = []
    for (let i = 0; i < allNetworks.length; i++) {
      const n = allNetworks[i]
      if (!n.known && !n.connected) {
        out.push(n)
      }
    }
    out.sort((a, b) => root.sortValue(b) - root.sortValue(a))
    return out
  }
  readonly property var rows: {
    const out = []
    if (connectedNetwork) {
      out.push({
        kind: "label",
        section: "connected",
        text: "Connected"
      })
      if (root.connectedExpanded) {
        out.push({
          kind: "connected",
          section: "connected",
          itemKey: connectedNetwork.name,
          active: !!connectedNetwork.connected
        })
      }
    }
    if (savedNetworks.length > 0) {
      out.push({
        kind: "label",
        section: "saved",
        text: "Saved"
      })
      if (root.savedExpanded) {
        for (let i = 0; i < savedNetworks.length; i++) {
          out.push({
            kind: "net",
            section: "saved",
            itemKey: savedNetworks[i].name,
            active: !!savedNetworks[i].connected
          })
        }
      }
    }
    if (availableNetworks.length > 0) {
      out.push({
        kind: "label",
        section: "available",
        text: "Available"
      })
      if (root.availableExpanded) {
        for (let i = 0; i < availableNetworks.length; i++) {
          out.push({
            kind: "net",
            section: "available",
            itemKey: availableNetworks[i].name,
            active: !!availableNetworks[i].connected
          })
        }
      }
    }
    return out
  }
  onAllNetworksChanged: {
    root.pruneFlowState()
    root.rebuildSortStrength()
  }
  onInteractingChanged: if (!root.interacting) {
    root.rebuildSortStrength()
  }
  onEnabledChanged: {
    if (!root.enabled) {
      root.closeScanCard()
      return
    }
    if (!root.open) {
      return
    }
    root.maybeRescan()
  }
  onCardHoveredChanged: {
    if (cardHovered) {
      root.maybeRescan()
    }
  }
  function sortValue(network) {
    const s = root.sortStrength[network.name]
    return s === undefined ? (network.signalStrength || 0) : s
  }
  function rebuildSortStrength() {
    if (root.interacting) {
      return
    }
    for (let i = 0; i < allNetworks.length; i++) {
      if (allNetworks[i].stateChanging) {
        return
      }
    }
    const next = {}
    for (let i = 0; i < allNetworks.length; i++) {
      next[allNetworks[i].name] = allNetworks[i].signalStrength || 0
    }
    root.sortStrength = next
  }
  function pruneFlowState() {
    if (root.pending !== "" && !root.findNetwork(root.pending)) {
      root.pending = ""
    }
    if (root.confirmForget !== "" && !root.findNetwork(root.confirmForget)) {
      root.confirmForget = ""
    }
    if (root.expanded !== "" && !root.findNetwork(root.expanded)) {
      root.expanded = ""
    }
  }
  function closeRowFlows() {
    root.pending = ""
    root.confirmForget = ""
    root.expanded = ""
    root.sharing = ""
  }
  function closeSectionFlows(section) {
    if (root.pending !== "" && root.rowSection(root.pending) === section) {
      root.pending = ""
    }
    if (root.confirmForget !== "" && root.rowSection(root.confirmForget) === section) {
      root.confirmForget = ""
    }
    if (root.expanded !== "" && root.rowSection(root.expanded) === section) {
      root.expanded = ""
    }
  }
  function rowSection(name) {
    const net = root.findNetwork(name)
    if (!net) {
      return ""
    }
    if (net.connected) {
      return root.connectedNetwork && name === root.connectedNetwork.name ? "connected" : ""
    }
    return net.known ? "saved" : "available"
  }
  function applySection(section, value) {
    if (section === "connected") {
      root.connectedExpanded = value
    } else if (section === "saved") {
      root.savedExpanded = value
    } else if (section === "available") {
      root.availableExpanded = value
    } else {
      return false
    }
    if (!value) {
      root.closeSectionFlows(section)
    }
    root.sharing = ""
    if (root.pending !== "" || root.confirmForget !== "") {
      root.focusKeyCatcher()
    }
    return true
  }
  function toggleSection(section) {
    return root.applySection(section, !root.sectionExpanded(section))
  }
  function sectionExpanded(section) {
    if (section === "connected") {
      return root.connectedExpanded
    }
    if (section === "saved") {
      return root.savedExpanded
    }
    if (section === "available") {
      return root.availableExpanded
    }
    return false
  }
  function signalPct(network) {
    const s = network && network.signalStrength ? network.signalStrength : 0
    return Math.round(s > 1 ? s : s * 100)
  }
  function glyphFor(network) {
    const pct = signalPct(network)
    if (pct > 66) {
      return "wifi-2"
    }
    if (pct > 33) {
      return "wifi-1"
    }
    return "wifi-0"
  }
  function secured(network) {
    return network.security !== WifiSecurityType.Open
  }
  function rescan() {
    if (!device || !root.open || root.scanOpen || scanProc.running) {
      return
    }
    root.device.scannerEnabled = true
    root.scanning = true
    root.scanInFlight = true
    scanProc.command = ["nmcli", "device", "wifi", "list", "ifname", device.name, "--rescan", "yes"]
    scanProc.running = true
    scanWatchdog.restart()
  }
  function lastRefreshAge() {
    return Date.now() - root.lastRefresh
  }
  function maybeRescan() {
    if (root.scanOpen || root.scanning || root.lastRefreshAge() <= 5000) {
      return
    }
    root.rescan()
  }
  function activate(network) {
    if (!network) {
      return
    }
    if (secured(network) && !network.known) {
      const wasPending = root.pending === network.name
      root.closeRowFlows()
      if (!wasPending) {
        root.pending = network.name
        root.showPassword = false
      }
      return
    }
    const wasExpanded = root.expanded === network.name
    root.closeRowFlows()
    if (!wasExpanded) {
      root.expanded = network.name
    }
  }
  function requestForget(network) {
    if (!network) {
      return
    }
    const keepExpanded = root.expanded
    const wasConfirm = root.confirmForget === network.name
    root.closeRowFlows()
    root.expanded = keepExpanded
    if (!wasConfirm) {
      root.confirmArmedAt = Date.now()
    }
    root.confirmForget = wasConfirm ? "" : network.name
  }
  function toggleExpanded(network) {
    if (!network) {
      return false
    }
    const wasExpanded = root.expanded === network.name
    root.closeRowFlows()
    if (!wasExpanded) {
      root.expanded = network.name
    }
    return true
  }
  function autoEnabled(name) {
    return root.autoConnect[name] !== false
  }
  function queryAutoConnect() {
    if (queryProc.running) {
      root.queryPending = true
      return
    }
    root.queryPending = false
    queryProc.command = ["nmcli", "-t", "-f", "NAME,AUTOCONNECT", "connection", "show"]
    queryProc.running = true
  }
  function setAutoConnect(name, value) {
    const next = {}
    for (const k in root.autoConnect) {
      next[k] = root.autoConnect[k]
    }
    next[name] = value
    root.autoConnect = next
    root.modifyQueue.push([name, value ? "yes" : "no"])
    root.pumpModify()
  }
  function pumpModify() {
    if (modifyProc.running || root.modifyQueue.length === 0) {
      return
    }
    const job = root.modifyQueue.shift()
    modifyProc.command = ["nmcli", "connection", "modify", job[0], "connection.autoconnect", job[1]]
    modifyProc.running = true
    root.modifyInFlight = true
    modifyWatchdog.restart()
  }
  function qrHasPassword(network) {
    if (!network) {
      return false
    }
    return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
  }
  function qrKind(network) {
    const s = network.security
    if (s === WifiSecurityType.StaticWep || s === WifiSecurityType.DynamicWep || s === WifiSecurityType.Leap) {
      return "WEP"
    }
    return "WPA"
  }
  function qrEscape(value) {
    return String(value).replace(/([\\;,":])/g, "\\$1")
  }
  function pskValid(network, text) {
    if (!network || text.length === 0) {
      return false
    }
    return root.qrKind(network) === "WEP" || text.length >= 8
  }
  function submitPsk() {
    const network = root.findNetwork(root.pending)
    if (!network) {
      root.pending = ""
      return false
    }
    const editor = root.editorForName(root.pending)
    const text = editor ? editor.text : ""
    if (!root.pskValid(network, text)) {
      return false
    }
    root.pskAttempt = root.pending
    network.connectWithPsk(text)
    root.pending = ""
    return true
  }
  function pskLoaded(name) {
    return root.pskCache[name] !== undefined
  }
  function qrPayload(name) {
    const network = root.findNetwork(name)
    if (!network || !network.known) {
      return ""
    }
    const ssid = root.qrEscape(network.name)
    if (!root.qrHasPassword(network)) {
      return "WIFI:T:nopass;S:" + ssid + ";;"
    }
    const psk = root.pskCache[name]
    if (psk === undefined || psk === "") {
      return ""
    }
    return "WIFI:T:" + root.qrKind(network) + ";S:" + ssid + ";P:" + root.qrEscape(psk) + ";;"
  }
  function requestPsk(name) {
    if (!name || root.pskLoaded(name)) {
      return
    }
    if (root.pskQueue.indexOf(name) < 0 && pskProc.target !== name) {
      root.pskQueue.push(name)
    }
    root.pumpPsk()
  }
  function pskProperty(name) {
    const network = root.findNetwork(name)
    if (!network) {
      return "802-11-wireless-security.psk"
    }
    if (network.security === WifiSecurityType.Leap) {
      return "802-11-wireless-security.leap-password"
    }
    if (root.qrKind(network) === "WEP") {
      return "802-11-wireless-security.wep-key0"
    }
    return "802-11-wireless-security.psk"
  }
  function pumpPsk() {
    if (pskProc.running || root.pskQueue.length === 0) {
      return
    }
    const name = root.pskQueue.shift()
    pskProc.target = name
    pskProc.output = ""
    pskProc.command = ["nmcli", "-s", "-g", root.pskProperty(name), "connection", "show", name]
    pskProc.running = true
    root.pskInFlight = true
    pskWatchdog.restart()
  }
  function storePsk(name, output) {
    const psk = output.replace(/\n+$/, "")
    const next = {}
    for (const k in root.pskCache) {
      if (k !== name && root.pskCache[k] !== "") {
        next[k] = root.pskCache[k]
      }
    }
    if (psk !== "") {
      next[name] = psk
    }
    root.pskCache = next
  }
  function dropPsk(name) {
    if (!name || root.pskCache[name] === undefined) {
      return
    }
    const next = {}
    for (const k in root.pskCache) {
      if (k !== name) {
        next[k] = root.pskCache[k]
      }
    }
    root.pskCache = next
  }
  function toggleSharing(network) {
    if (!network) {
      return false
    }
    const next = root.sharing === network.name ? "" : network.name
    root.sharing = next
    if (next !== "" && root.qrHasPassword(network)) {
      root.requestPsk(network.name)
    }
    return true
  }
  function startScan() {
    if (qrProc.running) {
      return
    }
    root.scanFrame = ""
    qrProc.command = ["bun", root.scanToolPath]
    qrProc.running = true
    scanFailTimer.restart()
  }
  function stopScan() {
    if (qrProc.running) {
      qrProc.running = false
    }
    root.scanFrame = ""
  }
  function scanHandleError(msg) {
    if (msg.error === "camera-unavailable") {
      root.scanPhase = "unavailable"
      root.scanStatus = "Camera unavailable"
      return true
    }
    if (msg.error === "missing-deps") {
      root.scanPhase = "missing"
      root.scanStatus = "Decoder missing"
      return true
    }
    if (msg.error === "no-image") {
      root.scanStatus = "No image in clipboard"
      return true
    }
    return false
  }
  function scanLine(data) {
    const line = data.trim()
    if (line === "") {
      return
    }
    let msg
    try {
      msg = JSON.parse(line)
    } catch (e) {
      return
    }
    if (root.scanHandleError(msg)) {
      return
    }
    if (msg.payload !== undefined) {
      root.handleScanPayload(msg.payload)
      return
    }
    if (msg.frame !== undefined) {
      root.scanFrame = msg.frame
    }
  }
  function decodeLine(data) {
    const line = data.trim()
    if (line === "") {
      return
    }
    let msg
    try {
      msg = JSON.parse(line)
    } catch (e) {
      return
    }
    if (root.scanHandleError(msg)) {
      return
    }
    if (msg.payload === undefined) {
      return
    }
    root.scanLastPayload = msg.payload
    if (root.decodeMode === "file") {
      root.scanDecoded = root.parseWifiPayload(msg.payload)
      return
    }
    root.handleScanPayload(msg.payload)
  }
  function scanProcExited(code) {
    if (!root.scanOpen || root.scanPhase === "connecting") {
      return
    }
    if (code === 2) {
      root.scanPhase = "unavailable"
      root.scanStatus = "Camera unavailable"
      return
    }
    if (code === 3) {
      root.scanPhase = "missing"
      root.scanStatus = "Decoder missing"
      return
    }
    root.scanPhase = "error"
    root.scanStatus = "Scan stopped"
  }
  function parseWifiPayload(text) {
    if (text.indexOf("WIFI:") !== 0) {
      return null
    }
    const body = text.slice(5)
    const fields = []
    let cur = ""
    let esc = false
    for (let i = 0; i < body.length; i++) {
      const c = body[i]
      if (esc) {
        cur += c
        esc = false
        continue
      }
      if (c === "\\") {
        esc = true
        continue
      }
      if (c === ";") {
        fields.push(cur)
        cur = ""
        continue
      }
      cur += c
    }
    fields.push(cur)
    const out = {
      hidden: false,
      psk: ""
    }
    for (let i = 0; i < fields.length; i++) {
      const idx = fields[i].indexOf(":")
      if (idx < 0) {
        if (fields[i] === "H") {
          out.hidden = true
        }
        continue
      }
      if (idx === 0) {
        continue
      }
      const key = fields[i].slice(0, idx)
      const value = fields[i].slice(idx + 1)
      if (key === "T") {
        out.security = value
      } else if (key === "S") {
        out.ssid = value
      } else if (key === "P") {
        out.psk = value
      } else if (key === "H") {
        out.hidden = value === "true" || value === "h"
      }
    }
    if (!out.ssid) {
      return null
    }
    if (out.security === "WPA2" || out.security === "WPA3") {
      out.security = "WPA"
    }
    if (!out.security || out.security === "nopass") {
      out.security = "nopass"
      out.psk = ""
    } else if (out.security !== "WPA" && out.security !== "WEP") {
      return null
    }
    if (out.security !== "nopass" && out.psk === "") {
      return null
    }
    return out
  }
  function handleScanPayload(payload) {
    root.scanLastPayload = payload
    if (root.scanPhase === "connecting") {
      return
    }
    const parsed = root.parseWifiPayload(payload)
    if (!parsed) {
      root.scanStatus = "Not a Wi-Fi code"
      return
    }
    root.joinScanned(parsed)
  }
  function joinScanned(parsed) {
    if (!parsed) {
      return false
    }
    if (root.connectedNetwork && parsed.ssid === root.connectedNetwork.name) {
      root.scanStatus = "Already connected"
      return true
    }
    root.scanParsed = parsed
    root.scanTarget = parsed.ssid
    root.scanResumePhase = qrProc.running ? "scanning" : root.scanPhase
    root.scanPhase = "connecting"
    root.scanStatus = "Connecting to " + parsed.ssid + "..."
    const cmd = ["nmcli", "device", "wifi", "connect", parsed.ssid, "ifname", root.wifiIface()]
    if (parsed.hidden) {
      cmd.push("hidden", "yes")
    }
    if (parsed.security === "WPA" || parsed.security === "WEP") {
      cmd.push("password", parsed.psk)
    }
    joinProc.command = cmd
    joinProc.running = true
    root.joinInFlight = true
    joinWatchdog.restart()
    return true
  }
  function joinFailed(reason) {
    root.joinInFlight = false
    joinWatchdog.stop()
    Quickshell.execDetached(["notify-send", "-a", "opencode", "-u", "normal", "opencode", "Wi-Fi: connection to " + root.scanTarget + " failed (" + reason + ")"])
    if (!root.scanOpen || root.scanPhase !== "connecting") {
      return
    }
    root.scanPhase = root.scanResumePhase
    root.scanStatus = "Failed: " + reason
  }
  function openScanCard() {
    if (!root.enabled) {
      return false
    }
    if (root.scanOpen) {
      return true
    }
    root.closeRowFlows()
    root.scanOpen = true
    root.scanPhase = "scanning"
    root.scanStatus = "Scanning..."
    root.startScan()
    return true
  }
  function closeScanCard() {
    if (!root.scanOpen) {
      return false
    }
    root.scanOpen = false
    root.scanPhase = "idle"
    root.scanStatus = ""
    root.stopScan()
    root.focusKeyCatcher()
    return true
  }
  function pasteScan() {
    if (!root.scanOpen || decodeProc.running) {
      return false
    }
    root.decodeMode = "paste"
    decodeProc.command = ["bun", root.scanToolPath, "--paste"]
    decodeProc.running = true
    return true
  }
  function toggleScanCard() {
    return root.scanOpen ? root.closeScanCard() : root.openScanCard()
  }
  Process {
    id: qrProc
    running: false
    stdout: SplitParser {
      onRead: data => root.scanLine(data)
    }
    onExited: code => root.scanProcExited(code)
  }
  Timer {
    id: scanFailTimer
    interval: 600
    running: false
    onTriggered: if (root.scanOpen && root.scanPhase === "scanning" && !qrProc.running) {
      root.scanPhase = "missing"
      root.scanStatus = "Decoder missing"
    }
  }
  Process {
    id: decodeProc
    running: false
    stdout: SplitParser {
      onRead: data => root.decodeLine(data)
    }
  }
  Process {
    id: joinProc
    running: false
    stderr: StdioCollector {
      id: joinErr
    }
    onExited: code => {
      if (!root.joinInFlight) {
        return
      }
      const reason = joinErr.text.trim()
      if (code === 0) {
        root.joinInFlight = false
        joinWatchdog.stop()
        if (root.scanParsed && root.scanParsed.psk !== "") {
          root.storePsk(root.scanTarget, root.scanParsed.psk)
        }
        root.queryAutoConnect()
        root.closeScanCard()
        return
      }
      root.joinFailed(reason !== "" ? reason : "unknown error")
    }
  }
  Timer {
    id: joinWatchdog
    interval: 45000
    running: false
    onTriggered: if (root.joinInFlight) {
      if (joinProc.running) {
        joinProc.running = false
      }
      root.joinFailed("timed out")
    }
  }
  Process {
    id: scanProc
    running: false
    onExited: {
      root.scanning = false
      root.scanInFlight = false
      root.lastRefresh = Date.now()
      root.rebuildSortStrength()
    }
  }
  Timer {
    id: scanWatchdog
    interval: 10000
    running: false
    onTriggered: if (root.scanInFlight && !scanProc.running) {
      root.scanning = false
      root.scanInFlight = false
      root.rebuildSortStrength()
    }
  }
  Connections {
    target: root
    function onOpenChanged() {
      if (!root.open) {
        root.closeScanCard()
      }
      if (!root.open && root.device) {
        root.device.scannerEnabled = false
      }
    }
  }
  Process {
    id: queryProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const next = {}
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          const m = lines[i].match(/^(.*):(yes|no)$/)
          if (m) {
            next[m[1].replace(/\\:/g, ":")] = m[2] === "yes"
          }
        }
        root.autoConnect = next
      }
    }
    onExited: {
      if (root.queryPending) {
        root.queryPending = false
        root.queryAutoConnect()
      }
    }
  }
  Process {
    id: modifyProc
    running: false
    onExited: {
      root.modifyInFlight = false
      root.pumpModify()
      root.queryAutoConnect()
    }
  }
  Timer {
    id: modifyWatchdog
    interval: 10000
    running: false
    onTriggered: if (root.modifyInFlight && !modifyProc.running) {
      root.modifyInFlight = false
      root.queryAutoConnect()
    }
  }
  Process {
    id: pskProc
    running: false
    property string target: ""
    property string output: ""
    stdout: StdioCollector {
      onStreamFinished: pskProc.output = text
    }
    onExited: {
      root.pskInFlight = false
      root.storePsk(pskProc.target, pskProc.output)
      root.pumpPsk()
    }
  }
  Timer {
    id: pskWatchdog
    interval: 10000
    running: false
    onTriggered: if (root.pskInFlight && !pskProc.running) {
      root.pskInFlight = false
      root.pumpPsk()
    }
  }
  Timer {
    id: activatingTimer
    interval: 30000
    onTriggered: root.activating = ""
  }
  function rowDelegates() {
    const out = []
    const kids = list.contentItem.children
    for (let i = 0; i < kids.length; i++) {
      if (kids[i] && kids[i].objectName === "wifiRow") {
        out.push(kids[i])
      }
    }
    return out
  }
  function editorForName(name) {
    if (!name) {
      return null
    }
    const rows = root.rowDelegates()
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].itemKey === name) {
        return rows[i].passwordEditor
      }
    }
    return null
  }
  function findNetwork(name) {
    for (let i = 0; i < allNetworks.length; i++) {
      if (allNetworks[i].name === name) {
        return allNetworks[i]
      }
    }
    return null
  }
  function testBeginPassword(name) {
    const network = root.findNetwork(name)
    if (!network || !root.secured(network) || network.known) {
      return false
    }
    root.closeRowFlows()
    root.pending = name
    root.showPassword = false
    return true
  }
  function testSetPassword(text) {
    const editor = root.editorForName(root.pending)
    if (!editor) {
      return false
    }
    editor.text = text
    return true
  }
  function testPasswordEcho() {
    const editor = root.editorForName(root.pending)
    if (!editor) {
      return ""
    }
    return editor.echoMode === TextInput.Password ? "hidden" : "shown"
  }
  function testToggleShowPassword() {
    root.showPassword = !root.showPassword
    return root.showPassword
  }
  function testPasswordRect() {
    const editor = root.editorForName(root.pending)
    if (!editor) {
      return null
    }
    const point = editor.mapToItem(null, 0, 0)
    if (!point) {
      return null
    }
    return {
      x: point.x,
      y: point.y,
      width: editor.width,
      height: editor.height,
      echo: root.testPasswordEcho()
    }
  }
  function testSubmitPassword() {
    if (!root.pending) {
      return false
    }
    return root.submitPsk()
  }
  function testAskForget(name) {
    const network = root.findNetwork(name)
    if (!network) {
      return false
    }
    root.requestForget(network)
    return true
  }
  function testConfirmForget() {
    if (!root.confirmForget) {
      return false
    }
    const network = root.findNetwork(root.confirmForget)
    if (!network) {
      root.confirmForget = ""
      return false
    }
    network.forget()
    root.dropPsk(network.name)
    root.confirmForget = ""
    return true
  }
  function testCancelForget() {
    if (!root.confirmForget) {
      return false
    }
    root.confirmForget = ""
    return true
  }
  function testToggleExpanded(name) {
    const network = root.findNetwork(name)
    if (!network) {
      return false
    }
    return root.toggleExpanded(network)
  }
  function testToggleAutoConnect(name) {
    const network = root.findNetwork(name)
    if (!network || !network.known) {
      return false
    }
    root.setAutoConnect(name, !root.autoEnabled(name))
    return true
  }
  function testSetSection(section, state) {
    return root.applySection(section, state === true)
  }
  function testToggleSharing(name) {
    const network = root.findNetwork(name)
    if (!network || !network.known) {
      return false
    }
    return root.toggleSharing(network)
  }
  function wifiIface() {
    return root.device ? root.device.name : ""
  }
  function testToggleSpeedtest() {
    if (!root.connectedNetwork) {
      return false
    }
    return Speedtest.toggle(root.connectedNetwork.name, root.wifiIface())
  }
  function testPreloadSpeedtest() {
    return Speedtest.preload()
  }
  function testMockSpeedtest(phase, down, up) {
    if (!root.connectedNetwork) {
      return false
    }
    return Speedtest.mock(root.connectedNetwork.name, phase, down, up)
  }
  function testScanOpen() {
    return root.openScanCard()
  }
  function testScanClose() {
    return root.closeScanCard()
  }
  function testScanState() {
    return {
      open: root.scanOpen,
      phase: root.scanPhase,
      status: root.scanStatus,
      frame: root.scanFrame !== "",
      lastPayload: root.scanLastPayload,
      decoded: root.scanDecoded,
      target: root.scanTarget,
      wifi: root.enabled
    }
  }
  function testScanDecodeFile(path) {
    if (decodeProc.running) {
      return false
    }
    root.decodeMode = "file"
    root.scanDecoded = null
    decodeProc.command = ["bun", root.scanToolPath, "--file", path]
    decodeProc.running = true
    return true
  }
  function testScanJoin() {
    if (!root.scanDecoded) {
      return false
    }
    return root.joinScanned(root.scanDecoded)
  }
  function testWifiState() {
    return {
      pending: root.pending,
      showPassword: root.showPassword,
      confirm: root.confirmForget,
      expanded: root.expanded,
      sharing: root.sharing,
      sharePayload: root.sharing !== "" ? root.qrPayload(root.sharing) : "",
      activating: root.activating,
      scanning: root.scanning,
      lastRefresh: root.lastRefresh,
      auto: root.autoConnect,
      connectedExpanded: root.connectedExpanded,
      savedExpanded: root.savedExpanded,
      availableExpanded: root.availableExpanded,
      connected: root.connectedNetwork ? root.connectedNetwork.name : "",
      saved: root.savedNetworks.map(n => n.name),
      available: root.availableNetworks.map(n => n.name),
      speedtest: Speedtest.state()
    }
  }
  onOpened: {
    if (root.device) {
      root.device.scannerEnabled = true
    }
    root.maybeRescan()
    root.rebuildSortStrength()
    closeRowFlows()
    pskAttempt = ""
    activating = ""
    showPassword = false
    scanOpen = false
    scanPhase = "idle"
    scanStatus = ""
    scanFrame = ""
    scanLastPayload = ""
    scanDecoded = null
    scanTarget = ""
    queryAutoConnect()
  }
  PanelHeader {
    title: "Wi-Fi"
    IconButton {
      name: "refresh"
      visible: root.enabled && root.rows.length > 0
      enabled: !root.scanning && !root.scanOpen
      iconColor: root.scanning ? Theme.overlay : Theme.text
      spinning: root.scanning
      onClicked: root.rescan()
    }
    IconButton {
      name: "camera"
      visible: root.enabled
      onClicked: root.toggleScanCard()
    }
    Switch {
      anchors.verticalCenter: parent.verticalCenter
      checked: root.enabled
      onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }
  }
  WifiScanCard {
    visible: root.scanOpen
    panel: root
  }
  PlaceholderCard {
    shown: !root.scanOpen && (!root.enabled || (root.enabled && root.rows.length === 0))
    instant: !root.enabled
    icon: !root.enabled ? "wifi-off" : "wifi"
    text: !root.enabled ? "Wi-Fi is off" : "Scanning"
    rolling: root.enabled && root.rows.length === 0
  }
  SectionList {
    id: list
    visible: root.enabled && count > 0 && !root.scanOpen
    height: visible ? contentHeight : 0
    entries: root.rows
    sections: ({
        connected: root.connectedExpanded,
        saved: root.savedExpanded,
        available: root.availableExpanded
      })
    onSectionToggled: root.toggleSection(section)
    delegate: Item {
      id: entry
      objectName: "wifiRow"
      required property string key
      required property string kind
      required property string section
      required property string label
      required property string itemKey
      required property bool active
      readonly property var net: entry.isLabel ? null : root.findNetwork(entry.itemKey)
      readonly property bool isLabel: entry.kind === "label"
      readonly property bool isConnected: entry.net ? entry.net.connected : entry.active
      readonly property bool pwOpen: !entry.isLabel && root.pending !== "" && root.pending === entry.itemKey
      readonly property bool confirmOpen: !entry.isLabel && root.confirmForget !== "" && root.confirmForget === entry.itemKey
      readonly property bool actionsOpen: !entry.isLabel && root.expanded !== "" && root.expanded === entry.itemKey && !entry.pwOpen && !entry.confirmOpen
      readonly property bool changing: entry.net ? entry.net.stateChanging : false
      readonly property bool busy: entry.changing || (!entry.isLabel && root.activating !== "" && root.activating === entry.itemKey)
      onChangingChanged: {
        if (entry.changing && !entry.isLabel && root.activating === entry.itemKey) {
          root.activating = ""
        }
        if (!entry.changing && !root.interacting) {
          root.rebuildSortStrength()
        }
      }
      Connections {
        target: entry.net
        function onConnectionFailed(reason) {
          if (root.pskAttempt !== entry.itemKey && root.activating !== entry.itemKey) {
            return
          }
          root.pskAttempt = ""
          root.activating = ""
          activatingTimer.stop()
          Quickshell.execDetached(["notify-send", "-a", "opencode", "-u", "normal", "opencode", "Wi-Fi: connection to " + entry.itemKey + " failed (" + ConnectionFailReason.toString(reason) + ")"])
        }
      }
      readonly property var passwordEditor: pwField
      readonly property bool highlighted: entry.isConnected || headerMouse.containsMouse || cardHover.containsMouse || pwHover.containsMouse || eyeBtn.hovered || passCheckBtn.hovered || forgetCancelBtn.hovered || forgetCheckBtn.hovered || trashActionBtn.hovered || qrActionBtn.hovered || toggleActionBtn.hovered || speedActionBtn.hovered || badgeHover.containsMouse
      readonly property bool shown: entry.isLabel ? true : list.isExpanded(entry.section)
      readonly property int qrSize: Math.round(entry.width * 0.5)
      readonly property bool qrOpen: !entry.isLabel && entry.actionsOpen && root.sharing === entry.itemKey
      readonly property string qrPayload: entry.isLabel ? "" : root.qrPayload(entry.itemKey)
      readonly property bool qrLoading: entry.qrOpen && entry.net ? (root.qrHasPassword(entry.net) && !root.pskLoaded(entry.itemKey)) : false
      readonly property bool qrMissing: entry.qrOpen && !entry.qrLoading && entry.qrPayload === ""
      readonly property bool speedActive: Speedtest.running && Speedtest.target === entry.itemKey
      readonly property bool speedFailed: Speedtest.error !== "" && Speedtest.target === entry.itemKey
      readonly property int qrFadeMs: 220
      property bool qrExpanded: false
      onQrOpenChanged: {
        if (entry.qrOpen) {
          qrCollapseTimer.stop()
          entry.qrExpanded = true
        } else {
          qrCollapseTimer.restart()
        }
      }
      Component.onCompleted: if (entry.qrOpen) {
        entry.qrExpanded = true
      }
      readonly property int actionsHeight: entry.qrExpanded ? entry.qrSize + Math.round(24 * Theme.scale) : Math.round(34 * Theme.scale)
      readonly property int extraHeight: (entry.pwOpen || entry.confirmOpen) ? Math.round(34 * Theme.scale) : (entry.actionsOpen ? entry.actionsHeight : 0)
      function revealRow() {
        root.ensureVisible(list.y + entry.y, Math.round(44 * Theme.scale) + entry.extraHeight)
      }
      onPwOpenChanged: if (entry.pwOpen) {
        Qt.callLater(entry.revealRow)
        revealTimer.restart()
      }
      onConfirmOpenChanged: if (entry.confirmOpen) {
        Qt.callLater(entry.revealRow)
        revealTimer.restart()
      }
      onActionsOpenChanged: if (entry.actionsOpen) {
        Qt.callLater(entry.revealRow)
        revealTimer.restart()
      }
      Timer {
        id: revealTimer
        interval: 240
        onTriggered: entry.revealRow()
      }
      readonly property color cardColor: entry.qrOpen ? Theme.qrSurface : (entry.highlighted ? Theme.surfaceHigh : Theme.surface)
      readonly property color hoverSurface: entry.qrOpen ? Theme.qrHover : Theme.surfaceHigher
      readonly property color strongText: entry.qrOpen ? Theme.crust : (entry.isConnected ? Theme.primary : Theme.text)
      readonly property color mutedText: entry.qrOpen ? Theme.overlay : Theme.subtext
      readonly property color accentText: entry.qrOpen ? Theme.crust : Theme.primary
      readonly property color hoverText: entry.qrOpen ? Theme.crust : Theme.text
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
      Timer {
        id: qrCollapseTimer
        interval: entry.qrFadeMs
        onTriggered: entry.qrExpanded = false
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
          onClicked: if (entry.net) {
            root.activate(entry.net)
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
              name: entry.net ? root.glyphFor(entry.net) : "wifi"
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
            text: entry.net ? entry.net.name : entry.itemKey
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
              visible: entry.net ? root.secured(entry.net) : false
              name: "lock"
              color: Theme.overlay
              font.pixelSize: Theme.fontSize
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: entry.net ? root.signalPct(entry.net) + "%" : ""
              color: entry.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              Behavior on color {
                ColorAnimation {
                  duration: 220
                  easing.type: Easing.OutCubic
                }
              }
            }
            Spinner {
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.busy && !entry.actionsOpen
              running: visible
              color: entry.accentText
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
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
              root.pending = ""
              event.accepted = true
            }
          }
          onVisibleChanged: if (visible) {
            pwField.text = ""
            pwField.forceActiveFocus()
          } else if (root.pending === "") {
            root.focusKeyCatcher()
          }
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
              onAccepted: root.submitPsk()
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
              onClicked: root.submitPsk()
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
              text: "Forget " + entry.itemKey + "?"
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
              onClicked: if (Date.now() - root.confirmArmedAt >= 250) {
                root.confirmForget = ""
              }
            }
            IconButton {
              id: forgetCheckBtn
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              name: "check"
              iconColor: Theme.red
              hoverColor: Theme.surfaceHigher
              onClicked: if (Date.now() - root.confirmArmedAt >= 250) {
                const network = root.findNetwork(root.confirmForget)
                if (network) {
                  network.forget()
                  root.dropPsk(network.name)
                }
                root.confirmForget = ""
              }
            }
          }
        }
        Item {
          visible: entry.actionsOpen
          width: parent.width
          anchors.top: parent.top
          anchors.topMargin: Math.round(44 * Theme.scale)
          height: visible ? entry.actionsHeight : 0
          clip: true
          QrCode {
            id: qrView
            x: Math.round(12 * Theme.scale)
            y: Math.round(12 * Theme.scale)
            width: entry.qrSize
            height: entry.qrSize
            text: entry.qrPayload
            opacity: entry.qrOpen && entry.qrPayload !== "" ? 1 : 0
            Behavior on opacity {
              NumberAnimation {
                duration: entry.qrFadeMs
                easing.type: Easing.OutCubic
              }
            }
          }
          Text {
            visible: entry.qrMissing
            anchors.left: parent.left
            anchors.leftMargin: Math.round(12 * Theme.scale)
            anchors.top: parent.top
            anchors.topMargin: Math.round(12 * Theme.scale)
            width: entry.qrSize
            text: "No key"
            color: Theme.overlay
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
          Item {
            x: Math.round(12 * Theme.scale)
            width: parent.width - Math.round(12 * Theme.scale) - Math.round(6 * Theme.scale)
            height: Math.round(20 * Theme.scale)
            y: Math.round(4 * Theme.scale)
            Row {
              visible: entry.isConnected && Speedtest.visibleFor(entry.itemKey)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Math.round(4 * Theme.scale)
              Icon {
                visible: Speedtest.down >= 0 || entry.speedFailed
                anchors.verticalCenter: parent.verticalCenter
                name: "download"
                color: entry.mutedText
                font.pixelSize: Theme.fontSizeSmall
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.speedFailed ? Speedtest.error : (Speedtest.down >= 0 ? Speedtest.text(Speedtest.down) : (Speedtest.running ? Speedtest.statusText() : "--"))
                color: entry.speedFailed ? Theme.red : entry.strongText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }
              Item {
                visible: Speedtest.up >= 0 && Speedtest.target === entry.itemKey
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(8 * Theme.scale)
                height: Math.round(8 * Theme.scale)
              }
              Icon {
                visible: Speedtest.up >= 0 && Speedtest.target === entry.itemKey
                anchors.verticalCenter: parent.verticalCenter
                name: "upload"
                color: entry.mutedText
                font.pixelSize: Theme.fontSizeSmall
              }
              Text {
                visible: Speedtest.up >= 0 && Speedtest.target === entry.itemKey
                anchors.verticalCenter: parent.verticalCenter
                text: Speedtest.text(Speedtest.up)
                color: entry.strongText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }
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
              onClicked: {
                if (!entry.net) {
                  return
                }
                root.activating = entry.net.name
                activatingTimer.restart()
                if (entry.isConnected) {
                  entry.net.disconnect()
                } else {
                  entry.net.connect()
                }
              }
            }
            Spinner {
              anchors.right: parent.right
              anchors.rightMargin: Math.round(2 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.busy
              running: visible
              color: entry.accentText
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
              iconColor: trashActionBtn.hovered ? entry.hoverText : Theme.overlay
              hoverColor: entry.hoverSurface
              onClicked: if (entry.net) {
                root.requestForget(entry.net)
              }
            }
            IconButton {
              id: qrActionBtn
              visible: entry.net ? entry.net.known : false
              anchors.right: trashActionBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              name: "qrcode"
              iconColor: entry.qrOpen ? entry.accentText : (qrActionBtn.hovered ? entry.hoverText : Theme.overlay)
              hoverColor: entry.hoverSurface
              onClicked: if (entry.net) {
                root.toggleSharing(entry.net)
              }
              Behavior on iconColor {
                ColorAnimation {
                  duration: 220
                  easing.type: Easing.OutCubic
                }
              }
            }
            Rectangle {
              id: autoToggleBtn
              visible: entry.net ? entry.net.known : false
              anchors.right: qrActionBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(44 * Theme.scale)
              height: Math.round(20 * Theme.scale)
              radius: height / 2
              color: badgeHover.containsMouse ? entry.hoverSurface : "transparent"
              antialiasing: true
              Text {
                anchors.centerIn: parent
                text: "AUTO"
                color: root.autoEnabled(entry.itemKey) ? entry.accentText : Theme.overlay
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: root.autoEnabled(entry.itemKey)
                Behavior on color {
                  ColorAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                  }
                }
              }
              MouseArea {
                id: badgeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (entry.net) {
                  root.setAutoConnect(entry.itemKey, !root.autoEnabled(entry.itemKey))
                }
              }
            }
            IconButton {
              id: speedActionBtn
              visible: entry.isConnected
              anchors.right: autoToggleBtn.left
              anchors.rightMargin: Math.round(4 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              size: Math.round(20 * Theme.scale)
              glyphSize: Math.round(13 * Theme.scale)
              name: "gauge"
              spinning: entry.speedActive
              iconColor: speedActionBtn.hovered ? entry.hoverText : Theme.overlay
              hoverColor: entry.hoverSurface
              onClicked: if (entry.net) {
                Speedtest.toggle(entry.net.name, root.wifiIface())
              }
              onHoveredChanged: if (speedActionBtn.hovered) {
                Speedtest.preload()
              }
            }
          }
        }
      }
    }
  }
}
