pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var applied: ({})
  property real startedAt: 0
  property real lastAudioAt: 0

  readonly property bool audioPlaying: {
    const list = Media.players
    if (!list) {
      return false
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i].isPlaying) {
        return true
      }
    }
    return false
  }

  readonly property bool running: Idle.active && IdleConfig.loaded && IdleConfig.enabled

  readonly property bool gateWaiting: {
    if (!root.running || IdleConfig.testArm !== null) {
      return false
    }
    const stage = IdleConfig.stage("suspend")
    if (!stage || !stage.enabled || root.applied["suspend"]) {
      return false
    }
    return root.elapsedSeconds() >= stage.afterSeconds && !root.gateSatisfied(stage)
  }

  function elapsedSeconds() {
    return startedAt > 0 ? (Date.now() - startedAt) / 1000 : 0
  }

  function silenceMs() {
    return lastAudioAt > 0 ? Date.now() - lastAudioAt : Number.MAX_VALUE
  }

  function gateSatisfied(stage) {
    if (!stage.audioGateSeconds) {
      return true
    }
    return silenceMs() >= stage.audioGateSeconds * 1000
  }

  function applyStage(kind) {
    if (kind === "dim") {
      if (!Brightness.dim()) {
        return
      }
    } else if (kind === "dpms") {
      Quickshell.execDetached(["hyprctl", "dispatch", "dpms off"])
    } else if (kind === "lock") {
      LockState.requestLock()
    } else if (kind === "suspend") {
      if (IdleConfig.testArm !== null) {
        return
      }
      LockState.lockAndSuspend()
    } else {
      return
    }
    const next = Object.assign({}, applied)
    next[kind] = true
    applied = next
  }

  function revertStage(kind) {
    if (kind === "dim") {
      Brightness.revert()
    } else if (kind === "dpms") {
      Quickshell.execDetached(["hyprctl", "dispatch", "dpms on"])
    }
  }

  function revertAll() {
    const kinds = Object.keys(applied)
    for (let i = 0; i < kinds.length; i++) {
      revertStage(kinds[i])
    }
    applied = {}
  }

  function handleWakeLine(message) {
    if (message.indexOf("PrepareForSleep") === -1 || message.indexOf("false") === -1) {
      return
    }
    if (!running) {
      return
    }
    revertAll()
    restartBaseline()
  }

  function tick() {
    if (startedAt <= 0) {
      return
    }
    if (audioPlaying) {
      lastAudioAt = Date.now()
    }
    const elapsed = elapsedSeconds()
    const stages = IdleConfig.stages
    for (let i = 0; i < stages.length; i++) {
      const stage = stages[i]
      if (!stage.enabled || applied[stage.kind] || stage.afterSeconds > elapsed) {
        continue
      }
      if (stage.kind === "suspend") {
        if (IdleConfig.testArm !== null || !gateSatisfied(stage)) {
          continue
        }
      }
      applyStage(stage.kind)
    }
  }

  function restartBaseline() {
    startedAt = Date.now() - IdleConfig.idleSeconds * 1000
    lastAudioAt = 0
  }

  Timer {
    id: idleTick

    interval: 1000
    running: root.running
    onRunningChanged: {
      if (running) {
        root.restartBaseline()
      } else {
        root.revertAll()
        root.startedAt = 0
      }
    }
    onTriggered: root.tick()
  }

  Connections {
    target: IdleConfig

    function onStagesChanged() {
      if (root.running) {
        root.restartBaseline()
      }
    }
  }

  Process {
    id: wakeProc

    running: true
    command: ["bash", "-lc", "exec gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: message => root.handleWakeLine(message)
    }
  }
}
