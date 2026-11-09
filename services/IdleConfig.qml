pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string file: "$HOME/.local/state/quickshell/idle.json"

  readonly property var defaultStages: [
    {
      kind: "dim",
      afterSeconds: 180,
      audioGateSeconds: 0
    },
    {
      kind: "dpms",
      afterSeconds: 300,
      audioGateSeconds: 0
    },
    {
      kind: "lock",
      afterSeconds: 330,
      audioGateSeconds: 0
    },
    {
      kind: "suspend",
      afterSeconds: 5400,
      audioGateSeconds: 1800
    }
  ]

  property bool enabled: true
  property int idleSeconds: 5
  property var stages: []
  property bool loaded: false
  property var testArm: null

  function stage(kind) {
    for (let i = 0; i < stages.length; i++) {
      if (stages[i].kind === kind) {
        return stages[i]
      }
    }
    return null
  }

  function arm(idleSeconds, overrides) {
    if (testArm !== null) {
      return false
    }
    const next = []
    for (let i = 0; i < stages.length; i++) {
      const entry = stages[i]
      const seconds = overrides && overrides[entry.kind] !== undefined ? overrides[entry.kind] : entry.afterSeconds
      next.push({
        kind: entry.kind,
        afterSeconds: seconds,
        enabled: entry.enabled,
        audioGateSeconds: entry.audioGateSeconds
      })
    }
    next.sort((a, b) => a.afterSeconds - b.afterSeconds)
    testArm = {
      idleSeconds: root.idleSeconds,
      stages: root.stages
    }
    if (typeof idleSeconds === "number" && isFinite(idleSeconds) && idleSeconds > 0) {
      root.idleSeconds = idleSeconds
    }
    root.stages = next
    return true
  }

  function disarm() {
    if (testArm === null) {
      return false
    }
    root.idleSeconds = testArm.idleSeconds
    root.stages = testArm.stages
    testArm = null
    return true
  }

  function posNum(value, fallback) {
    return typeof value === "number" && isFinite(value) && value > 0 ? value : fallback
  }

  function nonNegNum(value, fallback) {
    return typeof value === "number" && isFinite(value) && value >= 0 ? value : fallback
  }

  function flag(value, fallback) {
    return typeof value === "boolean" ? value : fallback
  }

  function normalize(data) {
    const valid = data !== null && data !== undefined && typeof data === "object" && !Array.isArray(data)
    const entries = {}
    if (valid && Array.isArray(data.stages)) {
      for (let i = 0; i < data.stages.length; i++) {
        const entry = data.stages[i]
        if (entry && typeof entry === "object" && !Array.isArray(entry) && typeof entry.kind === "string") {
          entries[entry.kind] = entry
        }
      }
    }
    const stages = []
    for (let i = 0; i < defaultStages.length; i++) {
      const base = defaultStages[i]
      const entry = entries[base.kind]
      stages.push({
        kind: base.kind,
        afterSeconds: entry ? posNum(entry.afterSeconds, base.afterSeconds) : base.afterSeconds,
        enabled: entry ? flag(entry.enabled, true) : true,
        audioGateSeconds: base.kind === "suspend" && entry ? nonNegNum(entry.audioGateSeconds, base.audioGateSeconds) : base.audioGateSeconds
      })
    }
    stages.sort((a, b) => a.afterSeconds - b.afterSeconds)
    root.enabled = valid ? flag(data.enabled, true) : true
    root.idleSeconds = valid ? posNum(data.idleSeconds, 5) : 5
    root.stages = stages
  }

  Process {
    id: readProc

    running: true
    command: ["bash", "-lc", "cat " + root.file + " 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.normalize(JSON.parse(text))
        } catch (e) {
          root.normalize(null)
        }
        root.loaded = true
      }
    }
  }
}
