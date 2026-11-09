pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property var applied: ({})
  property real startedAt: 0

  readonly property bool running: Idle.active && IdleConfig.loaded && IdleConfig.enabled

  function elapsedSeconds() {
    return startedAt > 0 ? (Date.now() - startedAt) / 1000 : 0
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

  function tick() {
    if (startedAt <= 0) {
      return
    }
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
    startedAt = Date.now() - IdleConfig.idleSeconds * 1000
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
}
