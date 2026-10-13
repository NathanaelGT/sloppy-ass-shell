pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/audio-priority.json"

  property var outputs: []
  property var inputs: []
  property bool loaded: false

  function list(kind) {
    return kind === "output" ? outputs : inputs
  }

  function assign(kind, names) {
    if (kind === "output") {
      outputs = names
    } else {
      inputs = names
    }
    save()
  }

  function merge(kind, names, seed) {
    const current = list(kind).slice()
    let changed = false
    if (current.length === 0 && seed && names.indexOf(seed) >= 0) {
      current.push(seed)
      changed = true
    }
    for (let i = 0; i < names.length; i++) {
      if (current.indexOf(names[i]) < 0) {
        current.push(names[i])
        changed = true
      }
    }
    if (changed) {
      assign(kind, current)
    }
  }

  function reorder(kind, name, target) {
    const current = list(kind).slice()
    const index = current.indexOf(name)
    if (index < 0) {
      return false
    }
    const clamped = Math.max(0, Math.min(current.length - 1, target))
    if (clamped === index) {
      return false
    }
    current.splice(index, 1)
    current.splice(clamped, 0, name)
    assign(kind, current)
    return true
  }

  function topPresent(kind, present) {
    const current = list(kind)
    for (let i = 0; i < current.length; i++) {
      if (present.indexOf(current[i]) >= 0) {
        return current[i]
      }
    }
    return ""
  }

  function remove(kind, name) {
    const current = list(kind).slice()
    const index = current.indexOf(name)
    if (index < 0) {
      return false
    }
    current.splice(index, 1)
    assign(kind, current)
    return true
  }

  function prune(kind, present, pinned) {
    const current = list(kind)
    const kept = []
    for (let i = 0; i < current.length; i++) {
      const name = current[i]
      if (present.indexOf(name) >= 0 || pinned.indexOf(name) >= 0) {
        kept.push(name)
      }
    }
    if (kept.length !== current.length) {
      assign(kind, kept)
    }
  }

  function save() {
    saveTimer.restart()
  }

  function flush() {
    const data = JSON.stringify({
      outputs: outputs,
      inputs: inputs
    })
    const escaped = data.replace(/'/g, "'\\''")
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + file + ")\"; printf '%s' '" + escaped + "' > " + file])
  }

  Timer {
    id: saveTimer

    interval: 150
    running: false
    repeat: false
    onTriggered: root.flush()
  }

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.file + " 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.outputs = data.outputs ? data.outputs : []
          root.inputs = data.inputs ? data.inputs : []
        } catch (e) {}
        root.loaded = true
      }
    }
  }
}
