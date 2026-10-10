pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/audio-app-icons.json"

  property var icons: ({})

  function cached(name) {
    const value = icons[name];
    return value ? value : "";
  }

  function remember(name, icon) {
    if (!name || !icon || icon === "application-x-executable") return;
    if (icons[name] === icon) return;
    const next = {};
    for (const key in icons) next[key] = icons[key];
    next[name] = icon;
    icons = next;
    save();
  }

  function forget(name) {
    if (icons[name] === undefined) return;
    const next = {};
    for (const key in icons) next[key] = icons[key];
    delete next[name];
    icons = next;
    save();
  }

  function save() {
    const data = JSON.stringify(icons);
    const escaped = data.replace(/'/g, "'\\''");
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + file + ")\"; printf '%s' '" + escaped + "' > " + file]);
  }

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.file + " 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text);
          root.icons = data ? data : {};
        } catch (e) {
        }
      }
    }
  }
}
