import QtQuick
import "../theme"

Item {
  id: root

  property SmoothScroll track: null
  readonly property bool engaged: hit.containsMouse || hit.pressed
  property real grabOffset: 0
  property bool jumping: false
  property real pressY: 0

  width: Theme.scrollThumbStrip

  function hitEnabled() {
    return hit.enabled
  }

  function contentFraction(y) {
    const t = root.track
    if (!t || !t.target || t.thumbTravel <= 0) {
      return null
    }
    return Math.max(0, Math.min(1, (y - root.grabOffset) / t.thumbTravel))
  }

  function dragTo(y) {
    const t = root.track
    const frac = root.contentFraction(y)
    if (frac === null) {
      return
    }
    t.positionTo(frac)
  }

  Rectangle {
    visible: root.track ? root.track.maxScroll > 0 : false
    x: Theme.scrollThumbStrip - Theme.scrollThumbGap - width
    width: Theme.scrollThumbHoverWidth
    height: parent.height
    radius: width / 2
    color: Theme.surfaceHigher
    opacity: root.engaged ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: 120
      }
    }
  }

  Rectangle {
    visible: root.track ? root.track.maxScroll > 0 : false
    opacity: root.track ? Math.max(root.track.hintOpacity, root.engaged ? 1 : 0) : 0
    x: Theme.scrollThumbStrip - Theme.scrollThumbGap - width
    y: root.track ? root.track.thumbY : 0
    width: root.engaged ? Theme.scrollThumbHoverWidth : Theme.scrollThumbWidth
    height: root.track ? root.track.thumbHeight : 0
    radius: width / 2
    color: root.engaged ? Theme.primary : Theme.surfaceHigher

    Behavior on width {
      NumberAnimation {
        duration: 120
      }
    }

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }
  }

  MouseArea {
    id: hit

    anchors.fill: parent
    enabled: root.visible && root.track !== null && root.track.maxScroll > 0
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (root.track) {
      root.track.bump()
    }
    onPressed: mouse => {
      const t = root.track
      if (!t) {
        return
      }
      t.dragActive = true
      t.beginDrag()
      root.pressY = mouse.y
      if (mouse.y >= t.thumbY && mouse.y <= t.thumbY + t.thumbHeight) {
        root.grabOffset = mouse.y - t.thumbY
        root.jumping = false
      } else {
        root.grabOffset = t.thumbHeight / 2
        root.jumping = true
        const frac = root.contentFraction(mouse.y)
        t.jumpTo(frac === null ? 0 : frac)
      }
    }
    onPositionChanged: mouse => {
      if (!pressed) {
        return
      }
      if (root.jumping) {
        if (Math.abs(mouse.y - root.pressY) <= Math.round(3 * Theme.scale)) {
          return
        }
        root.jumping = false
        root.track.snap()
      }
      root.dragTo(mouse.y)
    }
    onReleased: if (root.track) {
      root.jumping = false
      root.track.dragActive = false
      root.track.bump()
    }
    onCanceled: if (root.track) {
      root.jumping = false
      root.track.dragActive = false
      root.track.bump()
    }
    onWheel: event => {
      if (root.track) {
        root.track.wheel(event)
      }
      event.accepted = true
    }
  }
}
