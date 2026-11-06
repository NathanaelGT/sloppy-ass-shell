import QtQuick
import "../theme"
import "../services"

Item {
  id: root

  property string screenName: ""

  readonly property var entry: LockState.captureFor(screenName)

  function refresh() {
    if (root.entry.state === "captured") {
      img.source = ""
      img.source = "file://" + root.entry.path
    } else {
      img.source = ""
    }
  }

  onEntryChanged: root.refresh()

  Rectangle {
    anchors.fill: parent
    color: Theme.base
  }

  Image {
    id: img

    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    cache: false
    asynchronous: true
    opacity: 0
  }

  NumberAnimation {
    id: fadeIn

    target: img
    property: "opacity"
    to: 1
    duration: 500
    easing.type: Easing.InOutSine
  }

  Connections {
    target: img

    function onStatusChanged() {
      if (img.status === Image.Ready) {
        img.opacity = 0
        fadeIn.restart()
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.3
  }
}
