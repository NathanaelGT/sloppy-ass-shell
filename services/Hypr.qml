pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
  readonly property var workspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []
  readonly property var monitor: Hyprland.focusedMonitor
  readonly property string focusedScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  readonly property string activeWindowAddress: Hyprland.activeToplevel ? Hyprland.activeToplevel.address : ""

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
}
