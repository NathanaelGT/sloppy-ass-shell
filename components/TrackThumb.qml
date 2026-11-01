import QtQuick
import QtQuick.Effects
import "../theme"
import "../services"

Item {
  id: root

  property string file: ""
  property real size: 24

  width: s(size)
  height: s(size)

  function s(n) {
    return Math.round(n * Theme.scale)
  }
  function hairline() {
    return Math.max(1, Math.round(Theme.scale))
  }

  Component.onCompleted: Mpd.ensureTrackCover(root.file)

  Rectangle {
    id: thumbMask

    anchors.fill: parent
    visible: false
    radius: s(6)
    color: "white"
    antialiasing: true
    layer.enabled: true
  }

  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: thumbMask
      maskSpreadAtMin: 1.0
      maskThresholdMin: 0.5
    }

    Rectangle {
      anchors.fill: parent
      visible: Mpd.trackCover(root.file).length === 0
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: Theme.red
        }
        GradientStop {
          position: 1.0
          color: Theme.mauve
        }
      }
    }

    Image {
      anchors.fill: parent
      visible: Mpd.trackCover(root.file).length > 0
      source: Mpd.trackCover(root.file).length > 0 ? ("file://" + Mpd.trackCover(root.file)) : ""
      fillMode: Image.PreserveAspectCrop
      smooth: true
      mipmap: true
      sourceSize.width: s(60)
      sourceSize.height: s(60)
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: s(6)
    color: "transparent"
    antialiasing: true
    border.width: root.hairline()
    border.color: Qt.rgba(1, 1, 1, 0.2)
  }
}
