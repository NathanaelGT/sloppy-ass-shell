import QtQuick
import "../theme"
import "../components"
import "../services"

Rectangle {
  id: root

  property string kind: "dir"
  property string path: ""
  property string label: ""
  property bool activeSource: false
  signal open(string path)
  signal playRow(string path)

  readonly property string glyphIcon: root.activeSource ? "check" : root.kind === "pinned" ? "pin-filled" : root.kind === "favorites" ? "heart-filled" : "folder"
  readonly property color glyphColor: root.kind === "pinned" ? Theme.yellow : root.kind === "favorites" ? Theme.red : root.activeSource ? Theme.text : Theme.subtext

  width: parent ? parent.width : 0
  height: s(31)
  radius: s(8)
  color: root.activeSource ? Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, 0.18) : rowHover.containsMouse ? Theme.surface : "transparent"

  function s(n) {
    return Math.round(n * Theme.scale)
  }

  MouseArea {
    id: rowHover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.open(root.path)
  }

  Text {
    id: glyph

    x: s(12)
    width: s(13)
    anchors.verticalCenter: parent.verticalCenter
    horizontalAlignment: Text.AlignHCenter
    text: Icons.get(root.glyphIcon)
    font.family: Theme.iconFamily
    font.pixelSize: s(13)
    color: root.glyphColor
  }

  Text {
    id: label

    anchors.left: glyph.right
    anchors.leftMargin: s(8)
    anchors.right: count.left
    anchors.rightMargin: s(6)
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: s(10)
    elide: Text.ElideRight
  }

  Text {
    id: count

    anchors.right: playButton.visible ? playButton.left : parent.right
    anchors.rightMargin: playButton.visible ? s(4) : s(12)
    anchors.verticalCenter: parent.verticalCenter
    text: {
      if (root.kind === "pinned") {
        return Mpd.fmtCount(Object.keys(Mpd.pinned).length)
      }
      if (root.kind === "favorites") {
        return Mpd.fmtCount(Object.keys(Mpd.favorites).length)
      }
      const c = Mpd.counts[root.path]
      return c ? Mpd.fmtCount(c.songs) : ""
    }
    font.family: "monospace"
    font.pixelSize: s(10)
    color: Theme.subtext
  }

  Rectangle {
    id: playButton

    anchors.right: parent.right
    anchors.rightMargin: s(4)
    anchors.verticalCenter: parent.verticalCenter
    width: s(24)
    height: s(24)
    radius: s(6)
    visible: rowHover.containsMouse
    opacity: rowHover.containsMouse ? 1 : 0
    color: playHover.containsMouse ? Theme.surfaceHigher : "transparent"

    Text {
      anchors.centerIn: parent
      text: Icons.get("player-play")
      font.family: Theme.iconFamily
      font.pixelSize: s(12)
      color: Theme.text
    }

    MouseArea {
      id: playHover

      anchors.fill: parent
      enabled: rowHover.containsMouse
      cursorShape: Qt.PointingHandCursor
      onClicked: root.playRow(root.path)
    }
  }

  Component.onCompleted: {
    if (root.kind !== "dir" || root.path.length === 0) {
      return
    }
    if (!Mpd.counts[root.path]) {
      Mpd.fetchCount(root.path, () => {})
    }
  }
}
