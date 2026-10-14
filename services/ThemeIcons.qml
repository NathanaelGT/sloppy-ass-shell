pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string theme: Quickshell.env("QT_QPA_SYSTEM_ICON_THEME")

  property var names: ({})
  property bool loaded: false

  function themeName() {
    return root.theme && root.theme.length > 0 ? root.theme : "hicolor"
  }

  function has(name) {
    if (!name) {
      return false
    }
    return root.names[String(name)] === true
  }

  function scanCommand() {
    const theme = root.themeName()
    return "dirs=\"$HOME/.local/share/icons\"\n" + "for d in $(printf '%s' \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr ':' ' '); do dirs=\"$dirs $d/icons\"; done\n" + "for base in $dirs; do\n" + "  for name in " + theme + " hicolor; do\n" + "    [ -d \"$base/$name\" ] || continue\n" + "    find -L \"$base/$name\" -type f \\( -name '*.svg' -o -name '*.png' -o -name '*.xpm' \\) 2>/dev/null\n" + "  done\n" + "done | sed -E 's|.*/||; s|\\.[^.]+$||' | sort -u"
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
        root.names = found
        root.loaded = true
      }
    }
  }
}
