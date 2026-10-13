pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
  id: root

  readonly property var sink: deferredSink
  readonly property var source: deferredSource
  readonly property var out: sink ? sink.audio : null
  readonly property var mic: source ? source.audio : null

  readonly property real volume: out ? out.volume : 0
  readonly property bool muted: out ? out.muted : false
  readonly property bool micMuted: mic ? mic.muted : false

  readonly property real maxVolume: 1.5
  readonly property string feedbackSound: "/run/current-system/sw/share/sounds/freedesktop/stereo/audio-volume-change.oga"

  property var deferredSink: null
  property var deferredSource: null
  property var streamTargets: ({})
  property var streamLastActive: ({})
  property double feedbackAt: 0
  property string outputSetSig: ""
  property string inputSetSig: ""

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function refreshDefaults() {
    deferredSink = Pipewire.preferredDefaultAudioSink ? Pipewire.preferredDefaultAudioSink : Pipewire.defaultAudioSink
    deferredSource = Pipewire.preferredDefaultAudioSource ? Pipewire.preferredDefaultAudioSource : Pipewire.defaultAudioSource
  }

  function setVolume(v) {
    if (out) {
      out.volume = Math.max(0, Math.min(maxVolume, v))
    }
    if (!root.muted) {
      root.playVolumeFeedback(root.volume)
    }
  }

  function changeVolume(delta) {
    setVolume(volume + delta)
  }

  function playVolumeFeedback(level) {
    const now = Date.now()
    if (now - root.feedbackAt < 250) {
      return
    }
    root.feedbackAt = now
    const clamped = Math.max(0, Math.min(1, level))
    if (clamped <= 0) {
      return
    }
    Quickshell.execDetached(["pw-play", "--volume", clamped.toFixed(2), root.feedbackSound])
  }

  function streamActive(node) {
    if (!node || !node.properties) {
      return false
    }
    return String(node.properties["pulse.corked"]) !== "true"
  }

  function streamSerial(node) {
    if (!node) {
      return ""
    }
    if (node.properties && node.properties["object.serial"]) {
      return String(node.properties["object.serial"])
    }
    return String(node.id)
  }

  function lastActiveMs(node) {
    const value = root.streamLastActive[streamSerial(node)]
    return value ? Number(value) : 0
  }

  function touchActiveStreams() {
    const seen = {}
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (node.properties && node.properties["application.name"] === "Quickshell Peak Detect") {
        continue
      }
      const cls = mediaClass(node)
      if (cls !== "Stream/Output/Audio" && cls !== "Stream/Input/Audio") {
        continue
      }
      const key = streamSerial(node)
      seen[key] = true
      if (streamActive(node)) {
        root.streamLastActive[key] = Date.now()
      }
    }
    for (const key in root.streamLastActive) {
      if (!seen[key]) {
        delete root.streamLastActive[key]
      }
    }
  }

  function wheelAdjust(node, angleDelta) {
    if (!node || !node.audio) {
      return
    }
    const notches = Math.max(1, Math.round(Math.abs(angleDelta) / 120))
    const step = 0.01 * notches
    node.audio.volume = Math.max(0, Math.min(maxVolume, node.audio.volume + (angleDelta > 0 ? step : -step)))
  }

  function toggleMute() {
    if (out) {
      out.muted = !out.muted
    }
    if (!root.muted) {
      root.playVolumeFeedback(root.volume)
    }
  }

  function toggleMicMute() {
    if (mic) {
      mic.muted = !mic.muted
    }
  }

  function refreshStreamTargets() {
    if (targetProc.running) {
      return
    }
    targetProc.running = true
  }

  function streamTargetName(stream) {
    if (!stream) {
      return ""
    }
    const value = root.streamTargets[String(stream.id)]
    return value ? value : ""
  }

  function setStreamTarget(stream, nodeName) {
    if (!stream) {
      return
    }
    const next = {}
    for (const key in root.streamTargets) {
      next[key] = root.streamTargets[key]
    }
    if (nodeName) {
      next[String(stream.id)] = nodeName
    } else {
      delete next[String(stream.id)]
    }
    root.streamTargets = next
  }

  function mediaClass(node) {
    if (!node || !node.properties) {
      return ""
    }
    const value = node.properties["media.class"]
    return value ? value : ""
  }

  function deviceNames(cls) {
    const out = []
    for (let i = 0; i < nodes.length; i++) {
      if (mediaClass(nodes[i]) === cls) {
        out.push(nodes[i].name)
      }
    }
    return out
  }

  function nodeByName(kind, name) {
    const cls = kind === "output" ? "Audio/Sink" : "Audio/Source"
    for (let i = 0; i < nodes.length; i++) {
      if (mediaClass(nodes[i]) === cls && nodes[i].name === name) {
        return nodes[i]
      }
    }
    return null
  }

  function enforceKind(kind, present) {
    const target = Priority.topPresent(kind, present)
    if (!target) {
      return
    }
    const current = kind === "output" ? Pipewire.preferredDefaultAudioSink : Pipewire.preferredDefaultAudioSource
    if (current && current.name === target) {
      return
    }
    const node = nodeByName(kind, target)
    if (!node) {
      return
    }
    if (kind === "output") {
      Pipewire.preferredDefaultAudioSink = node
    } else {
      Pipewire.preferredDefaultAudioSource = node
    }
  }

  function refreshPriority() {
    if (!Priority.loaded) {
      return
    }
    const output = deviceNames("Audio/Sink")
    const input = deviceNames("Audio/Source")
    const outputDefault = Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : ""
    const inputDefault = Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.name : ""
    Priority.merge("output", output, outputDefault)
    Priority.merge("input", input, inputDefault)
    if (Pipewire.ready) {
      Priority.prune("output", output, Pins.outputs)
      Priority.prune("input", input, Pins.inputs)
    }
    const outSig = output.slice().sort().join("|")
    const inSig = input.slice().sort().join("|")
    if (outSig !== outputSetSig) {
      outputSetSig = outSig
      enforceKind("output", output)
    }
    if (inSig !== inputSetSig) {
      inputSetSig = inSig
      enforceKind("input", input)
    }
  }

  function applyPriority() {
    enforceKind("output", deviceNames("Audio/Sink"))
    enforceKind("input", deviceNames("Audio/Source"))
  }

  Timer {
    id: priorityDebounce

    interval: 200
    running: false
    repeat: false
    onTriggered: root.refreshPriority()
  }

  Timer {
    id: activeTouchTimer

    interval: 2000
    running: true
    repeat: true
    onTriggered: root.touchActiveStreams()
  }

  Timer {
    id: defaultTimer

    interval: 0
    repeat: false
    onTriggered: root.refreshDefaults()
  }

  Connections {
    target: Pipewire

    function onDefaultAudioSinkChanged() {
      defaultTimer.restart()
    }

    function onDefaultAudioSourceChanged() {
      defaultTimer.restart()
    }

    function onDefaultConfiguredAudioSinkChanged() {
      defaultTimer.restart()
    }

    function onDefaultConfiguredAudioSourceChanged() {
      defaultTimer.restart()
    }

    function onReadyChanged() {
      if (Pipewire.ready) {
        root.refreshPriority()
      }
    }
  }

  Component.onCompleted: {
    refreshDefaults()
    refreshPriority()
    touchActiveStreams()
  }

  onNodesChanged: priorityDebounce.restart()

  Connections {
    target: Priority

    function onLoadedChanged() {
      if (Priority.loaded) {
        root.refreshPriority()
      }
    }
  }

  PwObjectTracker {
    objects: {
      const list = []
      if (root.sink) {
        list.push(root.sink)
      }
      if (root.source) {
        list.push(root.source)
      }
      return list
    }
  }

  Process {
    id: targetProc

    command: ["pw-metadata", "-n", "default"]
    stdout: StdioCollector {
      onStreamFinished: {
        const next = {}
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          const match = lines[i].match(/^update: id:(\d+) key:'target\.object' value:'(.*)' type:/)
          if (match) {
            next[match[1]] = match[2]
          }
        }
        root.streamTargets = next
      }
    }
  }
}
