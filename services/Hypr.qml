pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
  id: root

  readonly property var workspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []
  readonly property var monitor: Hyprland.focusedMonitor
  readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  readonly property string activeWindowAddress: Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""

  property var fullscreenMap: ({})
  property var tilelessMap: ({})
  property var workspaceMap: ({})
  property var specialMap: ({})
  property string monitorsText: ""
  property string clientsText: ""
  property bool stateBusy: false
  property bool stateQueued: false

  function mapBool(map, screen) {
    return map[screen] === true
  }

  function fullscreen(screen) {
    return mapBool(fullscreenMap, screen)
  }

  function tileless(screen) {
    return mapBool(tilelessMap, screen)
  }

  function isStateEvent(name) {
    return name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "movewindowv2" || name === "workspace" || name === "workspacev2" || name === "changefloatingmode" || name === "fullscreen" || name === "fullscreenstate" || name === "activespecial" || name === "activespecialv2" || name === "minimize" || name === "monitoradded" || name === "monitorremoved" || name === "configreloaded"
  }

  function recompute() {
    let clients = []
    let monitors = []
    try {
      clients = JSON.parse(clientsText)
      monitors = JSON.parse(monitorsText)
    } catch (e) {
      return
    }
    const fullByWs = {}
    const tiledByWs = {}
    for (let i = 0; i < clients.length; i++) {
      const client = clients[i]
      if (!client || client.mapped === false) {
        continue
      }
      const ws = client.workspace && client.workspace.name ? client.workspace.name : ""
      if (!ws) {
        continue
      }
      if (client.fullscreen === 2) {
        fullByWs[ws] = true
      }
      if (!client.floating) {
        tiledByWs[ws] = (tiledByWs[ws] || 0) + 1
      }
    }
    const nextFull = {}
    const nextTile = {}
    const nextWs = {}
    const nextSpecial = {}
    for (let m = 0; m < monitors.length; m++) {
      const mon = monitors[m]
      if (!mon || !mon.name) {
        continue
      }
      const special = mon.specialWorkspace && mon.specialWorkspace.name ? mon.specialWorkspace.name : ""
      const active = mon.activeWorkspace && mon.activeWorkspace.name ? mon.activeWorkspace.name : ""
      const ws = special || active
      nextSpecial[mon.name] = special
      nextWs[mon.name] = ws
      nextFull[mon.name] = fullByWs[ws] === true
      nextTile[mon.name] = (tiledByWs[ws] || 0) === 0
    }
    fullscreenMap = nextFull
    tilelessMap = nextTile
    workspaceMap = nextWs
    specialMap = nextSpecial
  }

  function refreshState() {
    if (stateBusy) {
      stateQueued = true
      return
    }
    stateBusy = true
    stateQueued = false
    monitorsProc.running = true
  }

  Process {
    id: monitorsProc

    command: ["hyprctl", "monitors", "-j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.monitorsText = text
        clientsProc.running = true
      }
    }
  }

  Process {
    id: clientsProc

    command: ["hyprctl", "clients", "-j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.clientsText = text
        root.recompute()
        root.stateBusy = false
        if (root.stateQueued) {
          root.refreshState()
        }
      }
    }
  }

  Timer {
    id: stateDebounce

    interval: 60
    running: false
    onTriggered: root.refreshState()
  }

  Component.onCompleted: refreshState()

  readonly property var toplevels: {
    const out = []
    for (let i = 0; i < workspaces.length; i++) {
      const list = workspaces[i].toplevels
      if (!list) {
        continue
      }
      const values = list.values ? list.values : list
      for (let j = 0; j < values.length; j++) {
        out.push(values[j])
      }
    }
    return out
  }

  function classFor(names) {
    const wanted = []
    for (let i = 0; i < names.length; i++) {
      const value = names[i] ? String(names[i]).toLowerCase() : ""
      if (value && wanted.indexOf(value) < 0) {
        wanted.push(value)
      }
    }
    for (let i = 0; i < wanted.length; i++) {
      for (let j = 0; j < toplevels.length; j++) {
        const cls = toplevels[j].lastIpcObject ? toplevels[j].lastIpcObject.class : ""
        if (cls && cls.toLowerCase() === wanted[i]) {
          return cls
        }
      }
    }
    for (let i = 0; i < wanted.length; i++) {
      for (let j = 0; j < toplevels.length; j++) {
        const cls = toplevels[j].lastIpcObject ? toplevels[j].lastIpcObject.class : ""
        if (!cls) {
          continue
        }
        const low = cls.toLowerCase()
        if (low.indexOf(wanted[i]) >= 0 || wanted[i].indexOf(low) >= 0) {
          return cls
        }
      }
    }
    return ""
  }

  function monitorFor(screen) {
    return Hyprland.monitorFor(screen)
  }

  function focusToplevel(address) {
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:0x" + address + "\" })"])
  }

  function focusWorkspace(id) {
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
  }

  function toggleSpecial(name) {
    const bare = name.indexOf("special:") === 0 ? name.slice("special:".length) : name
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"" + bare + "\")"])
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "activespecialv2") {
        Hyprland.refreshMonitors()
      }
      if (isStateEvent(event.name)) {
        stateDebounce.restart()
      }
    }
  }
}
