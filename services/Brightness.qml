pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property real level: 0
  property real intLevel: 0
  property real extLevel: 0
  property bool lastTouchedInt: true
  property var ddcMap: ({})
  property bool dimmed: false
  property var preDim: ({})
  property var dimDisplays: ({})
  property bool roundTrip: false
  property bool pendingRestore: false
  property bool dimQueued: false
  property bool restoreQueued: false
  property bool notifyUpdate: false
  property var changeQueue: []
  property var intQueue: []

  signal updated

  function parseDetect(text) {
    const map = {}
    let display = null
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const displayMatch = line.match(/^Display\s+(\d+)/)
      if (displayMatch) {
        display = parseInt(displayMatch[1], 10)
        continue
      }
      if (line.indexOf("Invalid display") === 0) {
        display = null
        continue
      }
      const connectorMatch = line.match(/DRM connector:\s*card\d+-(.+?)\s*$/)
      if (connectorMatch && display !== null && connectorMatch[1].indexOf("eDP") !== 0) {
        map[connectorMatch[1]] = display
      }
    }
    return map
  }

  function clampLevel(v) {
    return Math.min(1, Math.max(0, v))
  }

  function applyResult(text) {
    const parts = text.trim().split(/\s+/)
    let parsed = false
    if (parts.length >= 4) {
      const current = parseInt(parts[2], 10)
      const max = parseInt(parts[3], 10)
      if (!isNaN(current) && max > 0) {
        const v = current / max
        parsed = true
        if (parts[0] === "EXT") {
          if (root.changeQueue.length === 0) {
            root.extLevel = v
          }
        } else if (parts[0] === "INT") {
          root.intLevel = v
        }
      }
    }
    if (root.notifyUpdate) {
      root.notifyUpdate = false
      if (parsed) {
        root.level = root.lastTouchedInt ? root.intLevel : root.extLevel
        root.updated()
      }
    }
    runNext()
    runNextInt()
  }

  function script(delta) {
    const cases = Object.keys(ddcMap).map(name => "  " + name + ") disp=" + ddcMap[name] + " ;;").join("\n")
    const read = delta === null
    return ["cx=$(hyprctl cursorpos -j | tr -d ' \\n' | sed 's/.*\"x\":\\([-0-9]*\\).*/\\1/')", "cy=$(hyprctl cursorpos -j | tr -d ' \\n' | sed 's/.*\"y\":\\([-0-9]*\\).*/\\1/')", "mon=$(hyprctl monitors | awk -v cx=\"$cx\" -v cy=\"$cy\" '/^Monitor /{name=$2} / at /{split($0,a,\" at \"); split(a[2],at,\"x\"); split(a[1],sz,\"@\"); split(sz[1],wh,\"x\"); if (cx>=at[1] && cx<at[1]+wh[1] && cy>=at[2] && cy<at[2]+wh[2]) {print name; exit}}')", "disp=\"\"", "case \"$mon\" in", cases, "esac", read ? "DELTA=\"\"" : "DELTA=" + delta, "clamp() { local v=$1; [ \"$v\" -lt 1 ] && v=1; [ \"$v\" -gt 100 ] && v=100; echo $v; }", "if [ -n \"$disp\" ]; then", "  if [ -z \"$DELTA\" ]; then", "    cur=$(ddcutil getvcp 10 --brief --display $disp 2>/dev/null | awk '{print $4}')", "    echo \"EXT $mon ${cur:-0} 100\"", "  else", "    cur=$(ddcutil getvcp 10 --brief --display $disp 2>/dev/null | awk '{print $4}')", "    new=$(clamp $(( ${cur:-0} + DELTA )))", "    ddcutil setvcp 10 $new --display $disp >/dev/null 2>&1", "    echo \"EXT $mon $new 100\"", "  fi", "elif [ -z \"$mon\" ] || [ \"$mon\" = \"eDP-1\" ]; then", "  if [ -z \"$DELTA\" ]; then", "    cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')", "    echo \"INT $mon ${cur:-0} 100\"", "  else", "    cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')", "    new=$(clamp $(( ${cur:-0} + DELTA )))", "    brightnessctl set ${new}% >/dev/null 2>&1", "    echo \"INT $mon $new 100\"", "  fi", "else", "  echo \"SKIP $mon 0 100\"", "fi"].join("\n")
  }

  function refresh() {
    if (workProc.running || refreshProc.running || changeQueue.length > 0) {
      return
    }
    refreshProc.command = ["bash", "-lc", script(null)]
    refreshProc.running = true
  }

  function detect() {
    detectProc.running = true
  }

  function change(delta) {
    if (Math.round(Math.abs(delta) * 100) <= 0) {
      return
    }
    root.intLevel = clampLevel(root.intLevel + delta)
    root.level = root.intLevel
    root.lastTouchedInt = true
    root.updated()
    enqueue(Math.round(delta * 100), false)
  }

  function changeExt(delta) {
    if (Object.keys(ddcMap).length === 0) {
      return
    }
    root.extLevel = clampLevel(root.extLevel + delta)
    root.level = root.extLevel
    root.lastTouchedInt = false
    root.updated()
    enqueue(Math.round(delta * 100), true)
  }

  function syncInt() {
    if (intSyncProc.running) {
      syncTimer.restart()
      return
    }
    intSyncProc.command = ["bash", "-lc", "cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')\necho \"INT eDP-1 ${cur:-0} 100\""]
    intSyncProc.running = true
  }

  function enqueue(delta, ext) {
    const queue = ext ? root.changeQueue : root.intQueue
    const last = queue.length > 0 ? queue[queue.length - 1] : null
    if (last && Math.abs(last.delta) < 30) {
      last.delta += delta
    } else {
      queue.push({
        delta: delta
      })
    }
    if (ext) {
      if (!workProc.running) {
        runNext()
      }
    } else {
      if (!intProc.running) {
        runNextInt()
      }
    }
  }

  function runNext() {
    if (workProc.running || changeQueue.length === 0) {
      return
    }
    if (Object.keys(ddcMap).length === 0) {
      changeQueue = []
      root.notifyUpdate = false
      return
    }
    const entry = changeQueue.shift()
    root.notifyUpdate = true
    workProc.command = ["bash", "-lc", extScript(entry.delta)]
    workProc.running = true
  }

  function runNextInt() {
    if (intProc.running || intQueue.length === 0) {
      return
    }
    const entry = intQueue.shift()
    root.notifyUpdate = true
    intProc.command = ["bash", "-lc", intScript(entry.delta)]
    intProc.running = true
  }

  function extScript(delta) {
    const names = Object.keys(ddcMap)
    const name = names[0]
    const disp = ddcMap[name]
    return ["clamp() { local v=$1; [ \"$v\" -lt 0 ] && v=0; [ \"$v\" -gt 100 ] && v=100; echo $v; }", "cur=$(ddcutil getvcp 10 --brief --display " + disp + " 2>/dev/null | awk '{print $4}')", "new=$(clamp $(( ${cur:-0} + " + delta + " )))", "ddcutil setvcp 10 $new --display " + disp + " >/dev/null 2>&1", "echo \"EXT " + name + " $new 100\""].join("\n")
  }

  function intScript(delta) {
    return ["clamp() { local v=$1; [ \"$v\" -lt 0 ] && v=0; [ \"$v\" -gt 100 ] && v=100; echo $v; }", "cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')", "new=$(clamp $(( ${cur:-0} + " + delta + " )))", "brightnessctl set ${new}% >/dev/null 2>&1", "echo \"INT eDP-1 $new 100\""].join("\n")
  }

  function dimScript() {
    const names = Object.keys(ddcMap)
    const lines = []
    for (let i = 0; i < names.length; i++) {
      const name = names[i]
      const disp = ddcMap[name]
      lines.push("cur=$(ddcutil getvcp 10 --brief --display " + disp + " 2>/dev/null | awk '{print $4}')")
      lines.push("if [ -z \"$cur\" ] || [ \"$cur\" = \"0\" ]; then echo \"SKIP " + name + "\"; else")
      lines.push("  echo \"DIM " + name + " $cur " + disp + "\"")
      lines.push("  ddcutil setvcp 10 0 --display " + disp + " >/dev/null 2>&1")
      lines.push("fi")
    }
    lines.push("cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')")
    lines.push("if [ -z \"$cur\" ] || [ \"$cur\" = \"0\" ]; then echo \"SKIP eDP-1\"; else")
    lines.push("  echo \"DIM eDP-1 $cur x\"")
    lines.push("  brightnessctl set 0% >/dev/null 2>&1")
    lines.push("fi")
    return lines.join("\n")
  }

  function restoreScript() {
    const names = Object.keys(preDim)
    const lines = []
    for (let i = 0; i < names.length; i++) {
      const name = names[i]
      const value = preDim[name]
      const display = root.dimDisplays[name]
      if (display !== undefined) {
        lines.push("ddcutil setvcp 10 " + value + " --display " + display + " >/dev/null 2>&1")
        lines.push("echo \"RST " + name + " " + value + " 100\"")
      }
    }
    if (preDim["eDP-1"] !== undefined) {
      lines.push("brightnessctl set " + preDim["eDP-1"] + "% >/dev/null 2>&1")
      lines.push("echo \"RST eDP-1 " + preDim["eDP-1"] + " 100\"")
    }
    return lines.join("\n")
  }

  function dim() {
    if (root.dimmed || dimProc.running) {
      return false
    }
    if (detectProc.running || workProc.running || changeQueue.length > 0 || intProc.running || intQueue.length > 0) {
      root.dimQueued = true
      retryTimer.restart()
      return false
    }
    root.dimQueued = false
    dimProc.command = ["bash", "-lc", dimScript()]
    dimProc.running = true
    return true
  }

  function revert() {
    if (dimProc.running) {
      root.pendingRestore = true
      return true
    }
    return restore()
  }

  function restore() {
    if (!root.dimmed) {
      root.roundTrip = false
      return false
    }
    if (restoreProc.running) {
      return false
    }
    if (detectProc.running || workProc.running || changeQueue.length > 0 || intProc.running || intQueue.length > 0) {
      root.restoreQueued = true
      retryTimer.restart()
      return false
    }
    root.restoreQueued = false
    restoreProc.command = ["bash", "-lc", restoreScript()]
    restoreProc.running = true
    return true
  }

  function applyDim(text) {
    const stored = {}
    const displays = {}
    const lines = text.trim().split("\n")
    for (let i = 0; i < lines.length; i++) {
      const parts = lines[i].trim().split(/\s+/)
      if (parts.length < 3 || parts[0] !== "DIM") {
        continue
      }
      const value = parseInt(parts[2], 10)
      stored[parts[1]] = isNaN(value) ? 0 : value
      const display = parseInt(parts[3], 10)
      if (!isNaN(display)) {
        displays[parts[1]] = display
      }
    }
    root.dimDisplays = displays
    root.preDim = stored
    root.dimmed = true
    root.intLevel = 0
    root.extLevel = 0
    root.level = 0
    if (root.pendingRestore) {
      root.pendingRestore = false
      restore()
      return
    }
    if (root.roundTrip) {
      roundTripTimer.restart()
    }
  }

  function applyRestore(text) {
    root.roundTrip = false
    root.dimmed = false
    const lines = text.trim().split("\n")
    for (let i = 0; i < lines.length; i++) {
      const parts = lines[i].trim().split(/\s+/)
      if (parts.length < 3 || parts[0] !== "RST") {
        continue
      }
      const value = parseInt(parts[2], 10)
      if (isNaN(value)) {
        continue
      }
      if (parts[1] === "eDP-1") {
        root.intLevel = value / 100
      } else {
        root.extLevel = value / 100
      }
    }
    root.level = root.lastTouchedInt ? root.intLevel : root.extLevel
    root.refresh()
  }

  function testRoundTrip() {
    Quickshell.execDetached(["notify-send", "-a", "opencode", "-u", "normal", "opencode", "idle chain round trip: dimming every monitor to 0, restoring in 4 s"])
    root.roundTrip = true
    if (!dim()) {
      roundTripTimer.restart()
    }
    return testState()
  }

  function testState() {
    return {
      dimmed: root.dimmed,
      roundTrip: root.roundTrip,
      preDim: root.preDim,
      level: root.level,
      intLevel: root.intLevel,
      extLevel: root.extLevel,
      queue: root.changeQueue.length,
      intQueue: root.intQueue.length,
      ddc: root.ddcMap
    }
  }

  Process {
    id: detectProc
    command: ["bash", "-lc", "ddcutil detect --brief 2>/dev/null"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        root.ddcMap = root.parseDetect(text)
        root.refresh()
      }
    }
  }

  Process {
    id: workProc
    command: ["bash", "-lc", "true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyResult(text)
    }
  }

  Process {
    id: intProc
    command: ["bash", "-lc", "true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyResult(text)
    }
  }

  Process {
    id: intSyncProc
    command: ["bash", "-lc", "true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyResult(text)
    }
  }

  Process {
    id: refreshProc
    command: ["bash", "-lc", "true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyResult(text)
    }
  }

  Process {
    id: dimProc
    command: ["bash", "-lc", "true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyDim(text)
    }
  }

  Process {
    id: restoreProc
    command: ["bash", "-lc", "true"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.applyRestore(text)
    }
  }

  Timer {
    id: roundTripTimer
    interval: 4000
    running: false
    onTriggered: root.restore()
  }

  Timer {
    id: syncTimer

    interval: 300
    running: false
    onTriggered: {
      if (root.intQueue.length === 0) {
        root.syncInt()
      }
    }
  }

  Timer {
    id: procWatchdog

    interval: 10000
    repeat: true
    running: dimProc.running || restoreProc.running
    onTriggered: {
      if (restoreProc.running) {
        restoreProc.running = false
        restore()
      } else if (dimProc.running) {
        dimProc.running = false
        dim()
      }
    }
  }

  Timer {
    id: retryTimer

    interval: 2500
    running: false
    onTriggered: {
      if (root.restoreQueued) {
        root.restoreQueued = false
        root.restore()
      } else if (root.dimQueued) {
        root.dimQueued = false
        root.dim()
      }
    }
  }

  Timer {
    interval: 1500
    repeat: true
    running: true
    onTriggered: {
      if (!dimProc.running && !restoreProc.running && !workProc.running) {
        root.detect()
      }
    }
  }
}
