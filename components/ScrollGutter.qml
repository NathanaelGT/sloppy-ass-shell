import QtQuick
import "../theme"

Item {
  id: root

  property SmoothScroll track: null
  readonly property bool engaged: hit.containsMouse || hit.pressed
  property real grabOffset: 0

  width: Theme.scrollThumbStrip

  function dragTo(y) {
    const t = root.track
    if (!t || !t.target || t.thumbTravel <= 0) {
      return
    }
    const nextY = Math.max(0, Math.min(t.thumbTravel, y - root.grabOffset))
    t.snap()
    t.target.contentY = nextY / t.thumbTravel * t.maxScroll
  }

  Rectangle {
    visible: root.track ? root.track.maxScroll > 0 : false
    opacity: root.track ? Math.max(root.track.hintOpacity, root.engaged ? 1 : 0) : 0
    x: Theme.scrollThumbGap
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
      t.snap()
      if (mouse.y >= t.thumbY && mouse.y <= t.thumbY + t.thumbHeight) {
        root.grabOffset = mouse.y - t.thumbY
      } else {
        root.grabOffset = t.thumbHeight / 2
        root.dragTo(mouse.y)
      }
    }
    onPositionChanged: mouse => {
      if (pressed) {
        root.dragTo(mouse.y)
      }
    }
    onReleased: if (root.track) {
      root.track.dragActive = false
      root.track.bump()
    }
    onCanceled: if (root.track) {
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
