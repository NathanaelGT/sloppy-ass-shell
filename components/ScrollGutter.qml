import QtQuick
import "../theme"

Item {
  id: root

  property SmoothScroll track: null

  width: Theme.scrollThumbStrip

  Rectangle {
    visible: root.track ? root.track.maxScroll > 0 : false
    opacity: root.track ? root.track.hintOpacity : 0
    x: Theme.scrollThumbGap
    y: root.track ? root.track.thumbY : 0
    width: Theme.scrollThumbWidth
    height: root.track ? root.track.thumbHeight : 0
    radius: width / 2
    color: Theme.surfaceHigher
  }
}
