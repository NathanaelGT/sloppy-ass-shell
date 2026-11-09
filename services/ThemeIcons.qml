pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/icon-index.json"
  readonly property string theme: Quickshell.env("QT_QPA_SYSTEM_ICON_THEME")

  property var names: ({})
  property bool loaded: false
  property bool scanDone: false

  function themeName() {
    return root.theme && root.theme.length > 0 ? root.theme : "hicolor"
  }

  function has(name) {
    if (!name) {
      return false
    }
    return root.names[String(name)] === true
  }

  function sameSet(a, b) {
    const ka = Object.keys(a).sort()
    const kb = Object.keys(b).sort()
    if (ka.length !== kb.length) {
      return false
    }
    for (let i = 0; i < ka.length; i++) {
      if (ka[i] !== kb[i]) {
        return false
      }
    }
    return true
  }

  function save() {
    const data = JSON.stringify(root.names)
    const escaped = data.replace(/'/g, "'\\''")
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + root.file + ")\"; printf '%s' '" + escaped + "' > " + root.file])
  }

  function rescan() {
    if (scan.running) {
      return
    }
    scan.running = true
  }

  function scanCommand() {
    const theme = root.themeName()
    return "dirs=\"$HOME/.local/share/icons\"\n" + "for d in $(printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' ' '); do dirs=\"$dirs $d/icons\"; done\n" + "for base in $dirs; do\n" + "  for name in " + theme + " hicolor; do\n" + "    [ -d \"$base/$name\" ] || continue\n" + "    fd --type f --hidden --no-ignore --follow --absolute-path --extension svg --extension png --extension xpm . \"$base/$name\" 2>/dev/null\n" + "  done\n" + "done | sed -E 's|.*/||; s|\\.[^.]+$||' | sort -u"
  }

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.file + " 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          if (!root.scanDone && data && typeof data === "object" && !Array.isArray(data)) {
            root.names = data
          }
        } catch (e) {}
        root.loaded = true
      }
    }
  }

  Process {
    id: scan

    running: true
    command: ["bash", "-lc", root.scanCommand()]
    stdout: StdioCollector {
      onStreamFinished: {
        const found = {}
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          const name = lines[i].trim()
          if (name.length > 0) {
            found[name] = true
          }
        }
        if (!root.sameSet(found, root.names)) {
          root.names = found
          root.save()
        }
        root.scanDone = true
        root.loaded = true
      }
    }
  }
}
