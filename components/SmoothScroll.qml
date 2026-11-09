import QtQuick
import "../theme"

Item {
  id: root

  property Flickable target: null
  property int step: Math.round(60 * Theme.scale)
  property int hideDelay: 800
  property real hintOpacity: 0
  property real pendingPx: 0
  property real animTarget: 0
  property real vel: 0
  property int glideDir: 0
  property real lastWheelMs: 0
  property bool chainRebound: false
  property real reboundTo: 0

  readonly property real maxScroll: target ? Math.max(0, target.contentHeight - target.height) : 0
  readonly property real visibleFrac: target && target.contentHeight > 0 ? Math.min(1, target.height / target.contentHeight) : 1
  readonly property real thumbHeight: Math.max(Math.round(28 * Theme.scale), root.height * root.visibleFrac)
  readonly property real thumbTravel: Math.max(0, root.height - root.thumbHeight)
  readonly property real thumbY: root.maxScroll > 0 ? root.thumbTravel * Math.max(0, Math.min(1, target.contentY / root.maxScroll)) : 0

  function bump() {
    root.hintOpacity = 1
    fadeTimer.restart()
  }

  function overClamp(raw) {
    const depth = Math.min(Theme.scrollOvershootCap, Math.abs(root.vel) * Theme.scrollOvershootVelMs)
    return Math.max(-depth, Math.min(root.maxScroll + depth, raw))
  }

  function armRebound(pos) {
    if (pos < 0 || pos > root.maxScroll) {
      root.reboundTo = pos < 0 ? 0 : root.maxScroll
      root.chainRebound = true
    }
  }

  function startRebound(pos) {
    reboundAnim.to = pos < 0 ? 0 : root.maxScroll
    reboundAnim.restart()
  }

  function chainStopped() {
    if (root.chainRebound) {
      root.chainRebound = false
      startRebound(root.reboundTo)
    }
  }

  function wheel(event) {
    const t = root.target
    if (!t || root.maxScroll <= 0) {
      return
    }
    if (event.pixelDelta.y !== 0) {
      root.pendingPx = 0
      root.chainRebound = false
      reboundAnim.stop()
      stepAnim.stop()
      glideAnim.stop()
      const before = t.contentY
      const applied = root.overClamp(before - event.pixelDelta.y)
      t.contentY = applied
      root.trackVelocity(applied - before)
      if (applied < 0 || applied > root.maxScroll) {
        root.startRebound(applied)
      }
      root.bump()
      return
    }
    root.notch(event.angleDelta.y)
  }

  function trackVelocity(movePx) {
    if (movePx === 0) {
      return
    }
    const now = Date.now()
    const dt = root.lastWheelMs > 0 ? Math.min(now - root.lastWheelMs, Theme.scrollVelocityWindowMs) : Theme.scrollVelocityWindowMs
    root.lastWheelMs = now
    const dir = movePx > 0 ? 1 : -1
    if (dir !== root.glideDir) {
      root.vel = 0
      root.glideDir = dir
    }
    const instV = Math.abs(movePx) / Math.max(dt, 1)
    root.vel += (instV - root.vel) * Theme.scrollVelocityBlend
    glideArm.restart()
  }

  function startGlide() {
    root.lastWheelMs = 0
    const t = root.target
    if (!t || root.maxScroll <= 0 || root.vel < Theme.scrollGlideMinVelocity) {
      root.vel = 0
      return
    }
    const base = stepAnim.running ? root.animTarget : t.contentY
    const cap = t.height * Theme.scrollGlideMaxFrac
    const extra = Math.max(-cap, Math.min(cap, root.vel * root.glideDir * Theme.scrollGlideTauMs))
    const want = root.overClamp(base + extra)
    root.vel = 0
    if (Math.abs(want - base) < 1) {
      return
    }
    root.chainRebound = false
    reboundAnim.stop()
    glideAnim.stop()
    stepAnim.stop()
    root.animTarget = want
    root.armRebound(want)
    glideAnim.to = want
    glideAnim.restart()
  }

  function notch(delta) {
    if (!root.target || root.maxScroll <= 0 || delta === 0) {
      return
    }
    root.bump()
    glideAnim.stop()
    const stepPx = -delta * root.step * Theme.scrollMultiplier / 120
    root.pendingPx += stepPx
    root.trackVelocity(stepPx)
    root.syncStep()
  }

  function syncStep() {
    const t = root.target
    const base = stepAnim.running ? root.animTarget : t.contentY
    const want = root.overClamp(base + root.pendingPx)
    root.pendingPx = 0
    if (want === base) {
      if (base < 0 || base > root.maxScroll) {
        root.armRebound(base)
        if (!stepAnim.running && !glideAnim.running) {
          root.startRebound(base)
        }
      }
      return
    }
    root.chainRebound = false
    reboundAnim.stop()
    glideAnim.stop()
    stepAnim.stop()
    root.animTarget = want
    root.armRebound(want)
    stepAnim.to = want
    stepAnim.restart()
  }

  function snap() {
    root.pendingPx = 0
    root.vel = 0
    root.lastWheelMs = 0
    root.chainRebound = false
    glideArm.stop()
    glideAnim.stop()
    stepAnim.stop()
    reboundAnim.stop()
  }

  Connections {
    target: root.target

    function onContentYChanged() {
      root.bump()
    }
  }

  NumberAnimation {
    id: stepAnim

    target: root.target
    property: "contentY"
    duration: 220
    easing.type: Easing.OutCubic
    onStopped: root.chainStopped()
  }

  NumberAnimation {
    id: glideAnim

    target: root.target
    property: "contentY"
    duration: Theme.scrollGlideDurationMs
    easing.type: Easing.OutCubic
    onStopped: root.chainStopped()
  }

  NumberAnimation {
    id: reboundAnim

    target: root.target
    property: "contentY"
    duration: Theme.scrollOvershootMs
    easing.type: Easing.OutCubic
  }

  Timer {
    id: glideArm

    interval: Theme.scrollGlideIdleMs
    running: false
    onTriggered: root.startGlide()
  }

  Behavior on hintOpacity {
    NumberAnimation {
      duration: 180
    }
  }

  Timer {
    id: fadeTimer

    interval: root.hideDelay
    running: false
    onTriggered: root.hintOpacity = 0
  }

  Rectangle {
    id: thumb

    visible: root.maxScroll > 0
    opacity: root.hintOpacity
    x: root.width - width - Math.max(2, Math.round(3 * Theme.scale))
    y: root.thumbY
    width: Math.max(3, Math.round(3 * Theme.scale))
    height: root.thumbHeight
    radius: width / 2
    color: Theme.surfaceHigher
  }
}
