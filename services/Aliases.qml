pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/audio-aliases.json"

  property var names: ({})

  function aliasFor(key) {
    const value = names[key]
    return value ? value : ""
  }

  function displayName(node) {
    if (!node) {
      return ""
    }
    return aliasFor(node.name) || (node.description && node.description.length > 0 ? node.description : node.name)
  }

  function setAlias(key, value) {
    const next = {}
    for (const name in names) {
      next[name] = names[name]
    }
    if (value && value.length > 0) {
      next[key] = value
    } else {
      delete next[key]
    }
    names = next
    save()
  }

  function save() {
    const data = JSON.stringify(names)
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
          root.names = data ? data : {}
        } catch (e) {}
      }
    }
  }
}
