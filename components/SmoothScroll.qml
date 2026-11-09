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
      t.contentY = Math.max(0, Math.min(root.maxScroll, t.contentY - event.pixelDelta.y))
      root.bump()
      return
    }
    root.notch(event.angleDelta.y)
  }

  function notch(delta) {
    if (!root.target || root.maxScroll <= 0 || delta === 0) {
      return
    }
    root.bump()
    root.pendingPx += -delta * root.step * Theme.scrollMultiplier / 120
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
