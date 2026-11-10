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
  property bool dragActive: false
  property int dragIndex: -1
  property real jumpFraction: 0
  property bool jumpArmed: false
  property real lastFraction: 0

  readonly property real maxScroll: target ? Math.max(0, target.contentHeight - target.height) : 0
  readonly property real visibleFrac: target && target.contentHeight > 0 ? Math.min(1, target.height / target.contentHeight) : 1
  readonly property bool listTarget: target !== null && target.positionViewAtIndex !== undefined
  property real listFraction: 0
  readonly property real scrollFraction: root.listTarget ? root.listFraction : (root.maxScroll > 0 ? Math.max(0, Math.min(1, target.contentY / root.maxScroll)) : 0)
  readonly property real thumbHeight: Math.max(Math.round(28 * Theme.scale), root.height * root.visibleFrac)
  readonly property real thumbTravel: Math.max(0, root.height - root.thumbHeight)
  readonly property real thumbY: root.thumbTravel * root.scrollFraction

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
      jumpAnim.stop()
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
    jumpAnim.stop()
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
    root.jumpArmed = false
    glideArm.stop()
    glideAnim.stop()
    stepAnim.stop()
    jumpAnim.stop()
    jumpFracAnim.stop()
    reboundAnim.stop()
  }

  function currentFraction() {
    if (root.listTarget) {
      return root.listFraction
    }
    return root.maxScroll > 0 ? Math.max(0, Math.min(1, root.target.contentY / root.maxScroll)) : 0
  }

  function updateListFraction() {
    const t = root.target
    if (!t || t.positionViewAtIndex === undefined || t.count <= 1) {
      return
    }
    const last = t.itemAtIndex(t.count - 1)
    if (last && last.y + last.height <= t.contentY + t.height + 0.5) {
      root.listFraction = 1
      return
    }
    let index = -1
    for (let y = 1; y < 48 && index < 0; y += 4) {
      index = t.indexAt(0, t.contentY + y)
    }
    if (index >= 0) {
      root.listFraction = index / (t.count - 1)
    }
  }

  function applyFraction(frac) {
    const t = root.target
    const f = Math.max(0, Math.min(1, frac))
    root.lastFraction = f
    if (t.positionViewAtIndex === undefined) {
      t.contentY = f * root.maxScroll
      return
    }
    if (t.count <= 0) {
      return
    }
    if (f >= 1) {
      root.dragIndex = -1
      const last = t.itemAtIndex(t.count - 1)
      if (last) {
        t.contentY = Math.max(0, last.y + last.height - t.height)
        return
      }
      t.positionViewAtIndex(t.count - 1, ListView.Visible)
      endSeek.restart()
      return
    }
    const index = Math.round(f * (t.count - 1))
    if (index === root.dragIndex) {
      return
    }
    root.dragIndex = index
    t.positionViewAtIndex(index, ListView.Beginning)
  }

  function positionTo(frac) {
    if (!root.target) {
      return
    }
    root.snap()
    root.applyFraction(frac)
    root.bump()
  }

  function beginDrag() {
    root.snap()
    root.dragIndex = -1
  }

  function jumpTo(frac) {
    const t = root.target
    if (!t || frac === null || frac === undefined || root.maxScroll <= 0) {
      return
    }
    root.snap()
    root.dragIndex = -1
    root.bump()
    const target = Math.max(0, Math.min(1, frac))
    if (t.positionViewAtIndex === undefined) {
      root.animTarget = target * root.maxScroll
      jumpAnim.to = root.animTarget
      jumpAnim.restart()
      return
    }
    root.jumpArmed = false
    root.jumpFraction = root.currentFraction()
    root.jumpArmed = true
    jumpFracAnim.from = root.jumpFraction
    jumpFracAnim.to = target
    jumpFracAnim.restart()
  }

  onJumpFractionChanged: if (root.jumpArmed) {
    root.applyFraction(root.jumpFraction)
  }

  Connections {
    target: root.target

    function onContentYChanged() {
      root.updateListFraction()
      root.bump()
    }

    function onContentHeightChanged() {
      root.updateListFraction()
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
    id: jumpAnim

    target: root.target
    property: "contentY"
    duration: 220
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: jumpFracAnim

    target: root
    property: "jumpFraction"
    duration: 220
    easing.type: Easing.OutCubic
    onStopped: if (root.jumpArmed) {
      root.jumpArmed = false
      root.applyFraction(root.jumpFraction)
    }
  }

  Timer {
    id: endSeek

    interval: 50
    onTriggered: {
      const t = root.target
      if (!t || root.lastFraction < 1 || t.positionViewAtIndex === undefined || t.count <= 0) {
        return
      }
      const last = t.itemAtIndex(t.count - 1)
      if (last) {
        t.contentY = Math.max(0, last.y + last.height - t.height)
      }
    }
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
}
