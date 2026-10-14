pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/launcher-favorites.json"

  property var items: []

  function has(key) {
    return items.indexOf(String(key)) >= 0
  }

  function toggle(key) {
    const list = items.slice()
    const text = String(key)
    const index = list.indexOf(text)
    if (index >= 0) {
      list.splice(index, 1)
    } else {
      list.push(text)
    }
    items = list
    save()
  }

  function save() {
    const data = JSON.stringify(items)
    const escaped = data.replace(/'/g, "'\\''")
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + file + ")\"; printf '%s' '" + escaped + "' > " + file])
  }

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.file + " 2>/dev/null || echo '[]'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          root.items = data && typeof data.length === "number" ? data : []
        } catch (e) {}
      }
    }
  }
}
