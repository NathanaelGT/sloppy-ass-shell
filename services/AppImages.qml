pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

Singleton {
  id: root

  readonly property var home: Quickshell.env("HOME")
  readonly property var platforms: ["linux", "x86", "x64", "x86_64", "amd64", "arm64", "aarch64", "nightly", "appimage", "universal"]
  readonly property string iconDir: root.home + "/.local/state/quickshell/appimage-icons"
  readonly property string iconIndexFile: root.home + "/.local/state/quickshell/appimage-icons.json"
  readonly property string iconScript: Quickshell.shellDir + "/services/appimage-icon.sh"

  property var resolved: ({})
  property var queue: []
  property bool indexLoaded: false
  property bool dirty: false

  FolderListModel {
    id: desktopDir

    folder: "file://" + root.home + "/Desktop"
    nameFilters: ["*.AppImage", "*.appimage"]
    showDirs: false
  }

  FolderListModel {
    id: downloadsDir

    folder: "file://" + root.home + "/Downloads"
    nameFilters: ["*.AppImage", "*.appimage"]
    showDirs: false
  }

  FolderListModel {
    id: documentsDir

    folder: "file://" + root.home + "/Documents"
    nameFilters: ["*.AppImage", "*.appimage"]
    showDirs: false
  }

  readonly property var available: {
    const found = []
    const models = [desktopDir, downloadsDir, documentsDir]
    for (let m = 0; m < models.length; m++) {
      const model = models[m]
      for (let i = 0; i < model.count; i++) {
        const path = String(model.get(i, "filePath"))
        const raw = String(model.get(i, "fileName"))
        found.push({
          path: path,
          raw: raw,
          dir: path.substring(0, path.lastIndexOf("/")),
          mtime: new Date(model.get(i, "fileModified")).getTime(),
          name: root.titleFrom(raw),
          detail: root.detailFrom(raw)
        })
      }
    }
    const newest = {}
    for (let i = 0; i < found.length; i++) {
      const image = found[i]
      const key = image.name.toLowerCase()
      const previous = newest[key]
      if (!previous || image.mtime > previous.mtime) {
        newest[key] = image
      }
    }
    const out = []
    for (const key in newest) {
      out.push(newest[key])
    }
    out.sort(function (a, b) {
      return a.name.localeCompare(b.name)
    })
    return out
  }

  function stemOf(raw) {
    return String(raw).replace(/\.[^.]*$/, "")
  }

  function keptParts(stem) {
    const parts = stem.split(/[-_.]+/).filter(function (part) {
      return part.length > 0
    })
    const kept = []
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i]
      if (/^[0-9]/.test(part) || root.platforms.indexOf(part.toLowerCase()) >= 0) {
        break
      }
      kept.push(part)
    }
    return kept
  }

  function titleFrom(raw) {
    const stem = root.stemOf(raw)
    const kept = root.keptParts(stem)
    const base = kept.length > 0 ? kept : (stem.length > 0 ? [stem.split(/[-_.]+/)[0]] : [stem])
    return base.map(function (part) {
      return /^[a-z][a-z]*$/.test(part) ? part.charAt(0).toUpperCase() + part.slice(1) : part
    }).join(" ")
  }

  function detailFrom(raw) {
    const stem = root.stemOf(raw)
    const kept = root.keptParts(stem)
    let rest = stem
    for (let i = 0; i < kept.length; i++) {
      const escaped = kept[i].replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
      rest = rest.replace(new RegExp("^[-_.]*" + escaped, "i"), "")
    }
    return rest.replace(/^[-_.]+/, "")
  }

  function hashKey(text) {
    let hash = 2166136261
    for (let i = 0; i < text.length; i++) {
      hash = Math.imul(hash ^ text.charCodeAt(i), 16777619)
    }
    return (hash >>> 0).toString(16)
  }

  function resolvedFor(path) {
    if (!path) {
      return null
    }
    const known = root.resolved[path]
    return known === undefined ? null : known
  }

  function iconFor(path) {
    const entry = root.resolvedFor(path)
    if (entry !== null) {
      return entry.icon
    }
    root.enqueue(path)
    return ""
  }

  function nameFor(path) {
    const entry = root.resolvedFor(path)
    if (entry !== null) {
      return entry.name
    }
    root.enqueue(path)
    return ""
  }

  function versionFor(path) {
    const entry = root.resolvedFor(path)
    if (entry !== null) {
      return entry.version
    }
    root.enqueue(path)
    return ""
  }

  function enqueue(path) {
    if (!path || root.queue.indexOf(path) >= 0 || root.resolved[path] !== undefined) {
      return
    }
    const next = root.queue.slice()
    next.push(path)
    root.queue = next
  }

  function resolveAvailable() {
    for (let i = 0; i < root.available.length; i++) {
      root.enqueue(root.available[i].path)
    }
  }

  function pump() {
    if (resolveProc.running) {
      return
    }
    if (root.queue.length === 0) {
      if (root.dirty) {
        root.dirty = false
        root.save()
      }
      return
    }
    const next = root.queue.slice()
    const path = next.shift()
    root.queue = next
    resolveProc.command = ["bash", root.iconScript, path, root.iconDir, root.hashKey(path)]
    resolveProc.running = true
  }

  function save() {
    const data = JSON.stringify(root.resolved)
    const escaped = data.replace(/'/g, "'\\''")
    Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$(dirname " + root.iconIndexFile + ")\"; printf '%s' '" + escaped + "' > " + root.iconIndexFile])
  }

  onAvailableChanged: if (root.indexLoaded) {
    root.resolveAvailable()
  }

  onIndexLoadedChanged: if (root.indexLoaded) {
    root.resolveAvailable()
  }

  onQueueChanged: Qt.callLater(root.pump)

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.iconIndexFile + " 2>/dev/null || echo '{}'; printf '\\n__FILES__\\n'; ls " + root.iconDir + " 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const marker = text.indexOf("__FILES__")
        const jsonText = marker >= 0 ? text.slice(0, marker).trim() : text.trim()
        const listing = marker >= 0 ? text.slice(marker + 9) : ""
        const files = {}
        const names = listing.split("\n")
        for (let i = 0; i < names.length; i++) {
          const name = names[i].trim()
          if (name.length > 0) {
            files[name] = true
          }
        }
        let data = {}
        try {
          data = JSON.parse(jsonText)
        } catch (error) {
          data = {}
        }
        const pruned = {}
        for (const key in data) {
          const entry = data[key]
          if (typeof entry === "string") {
            continue
          }
          const base = String(entry.icon ? entry.icon : "").split("/").pop()
          if (base.length > 0 && files[base]) {
            pruned[key] = entry
          }
        }
        root.resolved = pruned
        root.indexLoaded = true
      }
    }
  }

  Process {
    id: resolveProc

    running: false
    command: []
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n")
        const source = lines.length > 1 ? lines[0].trim() : ""
        if (source.length > 0) {
          const destination = lines.length > 1 ? lines[1].trim() : ""
          const name = lines.length > 2 ? lines[2].trim() : ""
          const version = lines.length > 3 ? lines[3].trim() : ""
          const next = {}
          for (const key in root.resolved) {
            next[key] = root.resolved[key]
          }
          next[source] = {
            icon: destination.length > 0 ? "file://" + destination : "",
            name: name,
            version: version
          }
          root.resolved = next
          root.dirty = true
        }
        Qt.callLater(root.pump)
      }
    }
  }
}
