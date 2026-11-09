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

  readonly property real maxScroll: target ? Math.max(0, target.contentHeight - target.height) : 0
  readonly property real visibleFrac: target && target.contentHeight > 0 ? Math.min(1, target.height / target.contentHeight) : 1
  readonly property real thumbHeight: Math.max(Math.round(28 * Theme.scale), root.height * root.visibleFrac)
  readonly property real thumbTravel: Math.max(0, root.height - root.thumbHeight)
  readonly property real thumbY: root.maxScroll > 0 ? root.thumbTravel * Math.max(0, Math.min(1, target.contentY / root.maxScroll)) : 0

  function bump() {
    root.hintOpacity = 1
    fadeTimer.restart()
  }

  function wheel(event) {
    const t = root.target
    if (!t || root.maxScroll <= 0) {
      return
    }
    if (event.pixelDelta.y !== 0) {
      root.pendingPx = 0
      stepAnim.stop()
      glideAnim.stop()
      const before = t.contentY
      t.contentY = Math.max(0, Math.min(root.maxScroll, before - event.pixelDelta.y))
      root.trackVelocity(t.contentY - before)
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
    const from = Math.max(0, Math.min(root.maxScroll, t.contentY))
    const base = stepAnim.running ? root.animTarget : from
    const cap = t.height * Theme.scrollGlideMaxFrac
    const extra = Math.max(-cap, Math.min(cap, root.vel * root.glideDir * Theme.scrollGlideTauMs))
    const want = Math.max(0, Math.min(root.maxScroll, base + extra))
    root.vel = 0
    if (Math.abs(want - base) < 1) {
      return
    }
    root.animTarget = want
    stepAnim.stop()
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
    const from = stepAnim.running ? root.animTarget : Math.max(0, Math.min(root.maxScroll, t.contentY))
    const want = Math.max(0, Math.min(root.maxScroll, from + root.pendingPx))
    root.pendingPx = 0
    if (want === from) {
      return
    }
    root.animTarget = want
    stepAnim.to = want
    stepAnim.restart()
  }

  function snap() {
    root.pendingPx = 0
    root.vel = 0
    root.lastWheelMs = 0
    glideArm.stop()
    glideAnim.stop()
    stepAnim.stop()
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
  }

  NumberAnimation {
    id: glideAnim

    target: root.target
    property: "contentY"
    duration: Theme.scrollGlideDurationMs
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
