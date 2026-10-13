pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/audio-pins.json"

  property var outputs: []
  property var inputs: []
  property var streams: []
  property var apps: []

  function isPinned(kind, name) {
    const list = kind === "output" ? outputs : inputs
    return list.indexOf(name) >= 0
  }

  function toggle(kind, name) {
    const list = (kind === "output" ? outputs : inputs).slice()
    const index = list.indexOf(name)
    if (index >= 0) {
      list.splice(index, 1)
    } else {
      list.push(name)
    }
    if (kind === "output") {
      outputs = list
    } else {
      inputs = list
    }
    save()
  }

  function isStreamPinned(key) {
    return streams.indexOf(key) >= 0
  }

  function isAppPinned(name) {
    return apps.indexOf(name) >= 0
  }

  function toggleApp(name) {
    const list = apps.slice()
    const index = list.indexOf(name)
    if (index >= 0) {
      list.splice(index, 1)
    } else {
      list.push(name)
    }
    apps = list
    save()
  }

  function reorderApp(name, target) {
    const list = apps.slice()
    const index = list.indexOf(name)
    if (index < 0) {
      return false
    }
    const clamped = Math.max(0, Math.min(list.length - 1, target))
    if (clamped === index) {
      return false
    }
    list.splice(index, 1)
    list.splice(clamped, 0, name)
    apps = list
    save()
    return true
  }

  function toggleStream(key) {
    const list = streams.slice()
    const index = list.indexOf(key)
    if (index >= 0) {
      list.splice(index, 1)
    } else {
      list.push(key)
    }
    streams = list
  }

  function save() {
    const data = JSON.stringify({
      outputs: outputs,
      inputs: inputs,
      apps: apps
    })
    const escaped = data.replace(/'/g, "'\\''")
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + file + ")\"; printf '%s' '" + escaped + "' > " + file])
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
          root.apps = data.apps ? data.apps : []
        } catch (e) {}
      }
    }
  }
}
