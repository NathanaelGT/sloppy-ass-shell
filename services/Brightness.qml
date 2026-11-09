pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property real level: 0
  property var ddcMap: ({})
  property bool dimmed: false
  property var preDim: ({})
  property bool roundTrip: false
  property bool pendingRestore: false

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
      if (connectorMatch && display !== null) {
        map[connectorMatch[1]] = display
      }
    }
    return map
  }

  function applyResult(text) {
    const parts = text.trim().split(/\s+/)
    if (parts.length < 4) {
      return
    }
    const current = parseInt(parts[2], 10)
    const max = parseInt(parts[3], 10)
    if (!isNaN(current) && max > 0) {
      level = current / max
    }
  }

  function script(delta) {
    const cases = Object.keys(ddcMap).map(name => "  " + name + ") disp=" + ddcMap[name] + " ;;").join("\n")
    const read = delta === null
    return ["cx=$(hyprctl cursorpos -j | tr -d ' \\n' | sed 's/.*\"x\":\\([-0-9]*\\).*/\\1/')", "cy=$(hyprctl cursorpos -j | tr -d ' \\n' | sed 's/.*\"y\":\\([-0-9]*\\).*/\\1/')", "mon=$(hyprctl monitors | awk -v cx=\"$cx\" -v cy=\"$cy\" '/^Monitor /{name=$2} / at /{split($0,a,\" at \"); split(a[2],at,\"x\"); split(a[1],sz,\"@\"); split(sz[1],wh,\"x\"); if (cx>=at[1] && cx<at[1]+wh[1] && cy>=at[2] && cy<at[2]+wh[2]) {print name; exit}}')", "disp=\"\"", "case \"$mon\" in", cases, "esac", read ? "DELTA=\"\"" : "DELTA=" + delta, "clamp() { local v=$1; [ \"$v\" -lt 1 ] && v=1; [ \"$v\" -gt 100 ] && v=100; echo $v; }", "if [ -n \"$disp\" ]; then", "  if [ -z \"$DELTA\" ]; then", "    cur=$(ddcutil getvcp 10 --brief --display $disp 2>/dev/null | awk '{print $4}')", "    echo \"EXT $mon ${cur:-0} 100\"", "  else", "    cur=$(ddcutil getvcp 10 --brief --display $disp 2>/dev/null | awk '{print $4}')", "    new=$(clamp $(( ${cur:-0} + DELTA )))", "    ddcutil setvcp 10 $new --display $disp >/dev/null 2>&1", "    echo \"EXT $mon $new 100\"", "  fi", "elif [ -z \"$mon\" ] || [ \"$mon\" = \"eDP-1\" ]; then", "  if [ -z \"$DELTA\" ]; then", "    cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')", "    echo \"INT $mon ${cur:-0} 100\"", "  else", "    cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')", "    new=$(clamp $(( ${cur:-0} + DELTA )))", "    brightnessctl set ${new}% >/dev/null 2>&1", "    echo \"INT $mon $new 100\"", "  fi", "else", "  echo \"SKIP $mon 0 100\"", "fi"].join("\n")
  }

  function refresh() {
    run(null)
  }

  function detect() {
    detectProc.running = true
  }

  function change(delta) {
    run(Math.round(delta * 100))
  }

  function run(delta) {
    workProc.command = ["bash", "-lc", script(delta)]
    workProc.running = true
  }

  function dimScript() {
    const names = Object.keys(ddcMap)
    const lines = []
    for (let i = 0; i < names.length; i++) {
      const name = names[i]
      const disp = ddcMap[name]
      lines.push("cur=$(ddcutil getvcp 10 --brief --display " + disp + " 2>/dev/null | awk '{print $4}')")
      lines.push("echo \"DIM " + name + " ${cur:-0} 100\"")
      lines.push("ddcutil setvcp 10 0 --display " + disp + " >/dev/null 2>&1")
    }
    lines.push("cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')")
    lines.push("echo \"DIM eDP-1 ${cur:-0} 100\"")
    lines.push("brightnessctl set 0% >/dev/null 2>&1")
    return lines.join("\n")
  }

  function restoreScript() {
    const names = Object.keys(preDim)
    const lines = []
    for (let i = 0; i < names.length; i++) {
      const name = names[i]
      const value = preDim[name]
      if (ddcMap[name] !== undefined && ddcMap[name] !== null) {
        lines.push("ddcutil setvcp 10 " + value + " --display " + ddcMap[name] + " >/dev/null 2>&1")
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
    if (root.dimmed || root.dimProc.running) {
      return false
    }
    dimProc.command = ["bash", "-lc", dimScript()]
    dimProc.running = true
    return true
  }

  function revert() {
    if (root.dimProc.running) {
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
    if (root.restoreProc.running) {
      return false
    }
    restoreProc.command = ["bash", "-lc", restoreScript()]
    restoreProc.running = true
    return true
  }

  function applyDim(text) {
    const stored = {}
    const lines = text.trim().split("\n")
    for (let i = 0; i < lines.length; i++) {
      const parts = lines[i].trim().split(/\s+/)
      if (parts.length < 3 || parts[0] !== "DIM") {
        continue
      }
      const value = parseInt(parts[2], 10)
      stored[parts[1]] = isNaN(value) ? 0 : value
    }
    root.preDim = stored
    root.dimmed = true
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

  function applyRestore() {
    root.roundTrip = false
    root.dimmed = false
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
      onStreamFinished: root.applyRestore()
    }
  }

  Timer {
    id: roundTripTimer
    interval: 4000
    running: false
    onTriggered: root.restore()
  }

  Timer {
    interval: 1500
    running: true
    onTriggered: root.detect()
  }
}
