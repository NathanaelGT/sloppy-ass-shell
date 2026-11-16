pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

Singleton {
  id: root

  property bool active: false

  property var panels: ({})
  property var bars: ({})
  property var osds: ({})

  property int shotSeq: 0
  property var shotResult: ({
      done: true,
      exitCode: 0,
      path: "",
      error: ""
    })

  function key(name, screen) {
    return name + "|" + screen
  }

  function withItem(source, key, item) {
    const next = {}
    for (const k in source) {
      next[k] = source[k]
    }
    next[key] = item
    return next
  }

  function withoutKey(source, key) {
    const next = {}
    for (const k in source) {
      if (k !== key) {
        next[k] = source[k]
      }
    }
    return next
  }

  function register(name, screen, item) {
    if (!name || !screen || !item) {
      return
    }
    root.panels = root.withItem(root.panels, root.key(name, screen), item)
  }

  function unregister(name, screen) {
    root.panels = root.withoutKey(root.panels, root.key(name, screen))
  }

  function panel(name, screen) {
    if (screen === undefined || screen === null) {
      for (const k in root.panels) {
        if (k.indexOf(name + "|") === 0 && root.panels[k].open) {
          return root.panels[k]
        }
      }
      for (const k in root.panels) {
        if (k.indexOf(name + "|") === 0) {
          return root.panels[k]
        }
      }
      return null
    }
    const item = root.panels[root.key(name, screen)]
    return item === undefined ? null : item
  }

  function registerBar(screen, item) {
    if (!screen || !item) {
      return
    }
    root.bars = root.withItem(root.bars, screen, item)
  }

  function bar(screen) {
    const item = root.bars[screen]
    return item === undefined ? null : item
  }

  function registerOsd(screen, item) {
    if (!screen || !item) {
      return
    }
    root.osds = root.withItem(root.osds, screen, item)
  }

  function unregisterOsd(screen) {
    if (!screen) {
      return
    }
    root.osds = root.withoutKey(root.osds, screen)
  }

  function osd(screen) {
    const item = root.osds[screen]
    return item === undefined ? null : item
  }

  function monitorRect(screen) {
    const target = screen && screen.length > 0 ? screen : "eDP-1"
    const screens = Quickshell.screens
    for (let i = 0; i < screens.length; i++) {
      if (screens[i].name !== target) {
        continue
      }
      const mon = Hyprland.monitorFor(screens[i])
      if (!mon) {
        return null
      }
      return {
        name: mon.name,
        x: Math.round(mon.x),
        y: Math.round(mon.y),
        width: Math.round(mon.width),
        height: Math.round(mon.height)
      }
    }
    return null
  }

  function barRect(screen) {
    const mon = root.monitorRect(screen)
    if (!mon) {
      return null
    }
    return {
      x: mon.x,
      y: mon.y,
      width: mon.width,
      height: Math.round(Theme.barThickness + Theme.shadowPad),
      monitor: mon.name
    }
  }

  function panelRect(name, screen) {
    const item = screen && screen.length > 0 ? root.panel(name, screen) : root.panel(name)
    if (!item || !item.open) {
      return null
    }
    const local = item.testRect()
    if (!local) {
      return null
    }
    const mon = root.monitorRect(item.screenId)
    if (!mon) {
      return null
    }
    return {
      x: mon.x + Math.round(local.x),
      y: mon.y + Math.round(local.y),
      width: Math.round(local.width),
      height: Math.round(local.height),
      monitor: mon.name
    }
  }

  function osdRect(screen) {
    const target = screen && screen.length > 0 ? screen : "eDP-1"
    const item = root.osd(target)
    if (!item) {
      return null
    }
    const local = item.testRect()
    if (!local) {
      return null
    }
    const mon = root.monitorRect(item.screenId)
    if (!mon) {
      return null
    }
    return {
      x: mon.x + Math.round(local.x),
      y: mon.y + mon.height - Math.round(item.height) + Math.round(local.y),
      width: Math.round(local.width),
      height: Math.round(local.height),
      monitor: mon.name
    }
  }

  function runShot(rect) {
    if (shotProc.running) {
      return {
        done: false,
        busy: true,
        path: ""
      }
    }
    root.shotSeq += 1
    const path = "/tmp/opencode/test-shot-" + root.shotSeq + ".png"
    root.shotResult = {
      done: false,
      exitCode: -1,
      path: path,
      error: ""
    }
    shotProc.command = ["/etc/profiles/per-user/nathanaelgt/bin/grim", "-g", Math.round(rect.x) + "," + Math.round(rect.y) + " " + Math.round(rect.width) + "x" + Math.round(rect.height), path]
    shotProc.running = true
    return {
      done: false,
      busy: false,
      path: path
    }
  }

  Process {
    id: shotProc

    stderr: StdioCollector {
      id: shotErr
    }
    onExited: exitCode => {
      root.shotResult = {
        done: true,
        exitCode: exitCode,
        path: root.shotResult.path,
        error: exitCode !== 0 ? shotErr.text : ""
      }
    }
  }
}
