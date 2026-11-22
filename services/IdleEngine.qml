pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var applied: ({})
  property bool mediaHold: false
  property real elapsedMs: 0
  property real lastTickAt: 0

  readonly property bool audioPlaying: {
    const list = Media.players
    if (list) {
      for (let i = 0; i < list.length; i++) {
        if (list[i].isPlaying) {
          return true
        }
      }
    }
    return Mpd.state === "play" && Mpd.streamNode !== null
  }

  readonly property bool running: Idle.active && IdleConfig.loaded && IdleConfig.enabled && (IdleConfig.testArm !== null || !mediaHold || LockState.sessionLocked)

  function elapsedSeconds() {
    return elapsedMs / 1000
  }

  function syncHold() {
    if (!audioPlaying) {
      holdArm.stop()
      mediaHold = false
      return
    }
    if (!mediaHold && !holdArm.running) {
      holdArm.restart()
    }
  }

  function applyStage(kind) {
    if (kind === "dim") {
      if (!Brightness.dim()) {
        return
      }
    } else if (kind === "dpms") {
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"off\" })"])
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
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"on\" })"])
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
    if (message.indexOf("System returned from sleep operation") === -1) {
      return
    }
    if (!running) {
      return
    }
    revertAll()
    restartBaseline()
  }

  function tick() {
    if (lastTickAt <= 0) {
      return
    }
    const now = Date.now()
    const delta = Math.min(Math.max(now - lastTickAt, 0), 5000)
    lastTickAt = now
    elapsedMs += delta
    const elapsed = elapsedSeconds()
    const stages = IdleConfig.stages
    for (let i = 0; i < stages.length; i++) {
      const stage = stages[i]
      if (!stage.enabled || applied[stage.kind] || stage.afterSeconds > elapsed) {
        continue
      }
      applyStage(stage.kind)
    }
  }

  function restartBaseline() {
    elapsedMs = (LockState.sessionLocked ? IdleConfig.lockedStartSeconds : IdleConfig.idleSeconds) * 1000
    lastTickAt = Date.now()
  }

  onAudioPlayingChanged: root.syncHold()

  Component.onCompleted: root.syncHold()

  Timer {
    id: holdArm

    interval: 3000
    repeat: false
    onTriggered: root.mediaHold = true
  }

  Timer {
    id: idleTick

    interval: 1000
    repeat: true
    running: root.running
    onRunningChanged: {
      if (running) {
        root.restartBaseline()
      } else {
        root.revertAll()
        root.elapsedMs = 0
        root.lastTickAt = 0
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

  Connections {
    target: LockState

    function onSessionLockedChanged() {
      if (LockState.sessionLocked) {
        root.restartBaseline()
      } else {
        root.revertAll()
        root.elapsedMs = 0
        root.lastTickAt = 0
      }
    }
  }

  Process {
    id: wakeProc

    running: true
    command: ["journalctl", "-f", "-n", "0", "-t", "systemd-sleep", "-o", "cat"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: message => root.handleWakeLine(message)
    }
  }
}
