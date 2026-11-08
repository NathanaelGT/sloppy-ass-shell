import QtQuick
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen
  property bool merged: false
  property real mergedSpan: 0

  readonly property real iconOnlyWidth: icon.implicitWidth + Math.round(16 * Theme.scale)

  property real seal: 1

  bottomLeftRadius: root.seal * root.radius
  bottomRightRadius: root.seal * root.radius

  Component.onCompleted: {
    root.seal = root.active ? 0 : 1
    TestDriver.register("musicPill", root.screen.name, root)
  }

  onActiveChanged: {
    if (!root.active) {
      return
    }
    sealAnim.stop()
    sealAnim.to = 0
    sealAnim.start()
  }

  Connections {
    target: Panels

    function onCloseCleared(name, screen) {
      if (name === "music" && screen === root.screen.name) {
        sealAnim.stop()
        sealAnim.to = 1
        sealAnim.start()
      }
    }
  }

  NumberAnimation {
    id: sealAnim

    target: root
    property: "seal"
    duration: 150
    easing.type: Easing.OutCubic
  }

  implicitWidth: root.merged ? Math.round(root.mergedSpan) + root.iconOnlyWidth : root.showingTitle ? titleLabel.implicitWidth + icon.implicitWidth + Math.round(26 * Theme.scale) : root.iconOnlyWidth
  active: Panels.openOn("music", root.screen.name)
  onClicked: Panels.toggle("music", root.screen.name)
  onRightClicked: Mpd.toggle(root.screen.name)
  onMiddleClicked: Quickshell.execDetached(["systemctl", "--user", "restart", "mpd"])
  onWheeled: delta => Mpd.setVolume(Mpd.volume + (delta > 0 ? 5 : -5))
  visible: Mpd.connected

  Behavior on implicitWidth {
    NumberAnimation {
      duration: 200
      easing.type: Easing.OutCubic
    }
  }

  Behavior on x {
    NumberAnimation {
      duration: 200
      easing.type: Easing.OutCubic
    }
  }

  Behavior on titleOpacity {
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }

  readonly property var song: Mpd.song
  readonly property bool menuOpen: Panels.openOn("music", root.screen ? root.screen.name : "")

  property bool showTitle: false
  property bool showingTitle: false
  property real titleOpacity: 0

  Timer {
    id: titleTimer

    interval: 5000
    repeat: false
    onTriggered: root.showTitle = false
  }

  Timer {
    id: growTimer

    interval: 150
    repeat: false
    onTriggered: root.titleOpacity = 1
  }

  Timer {
    id: shrinkTimer

    interval: 112
    repeat: false
    onTriggered: root.showingTitle = false
  }

  onShowTitleChanged: {
    if (root.showTitle && !root.menuOpen) {
      root.showingTitle = true
      shrinkTimer.stop()
      growTimer.restart()
    } else {
      root.titleOpacity = 0
      growTimer.stop()
      shrinkTimer.restart()
    }
  }

  onMenuOpenChanged: {
    if (root.menuOpen) {
      root.showTitle = false
    }
  }

  Connections {
    target: Mpd

    function onStateChanged() {
      if (Mpd.state !== "play") {
        root.showTitle = false
      }
    }

    function onTitleArrival(screen) {
      if (screen === root.screen.name && !root.menuOpen) {
        root.showTitle = true
        titleTimer.restart()
      }
    }
  }

  onSongChanged: {
    if (!root.song) {
      root.showTitle = false
      titleTimer.stop()
    }
  }

  Text {
    id: titleLabel

    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: Math.round(10 * Theme.scale)
    anchors.right: icon.left
    anchors.rightMargin: Math.round(8 * Theme.scale)
    horizontalAlignment: root.merged ? Text.AlignHCenter : Text.AlignLeft
    visible: root.showingTitle && root.song !== null && root.song.title.length > 0
    opacity: root.titleOpacity
    text: root.song ? (root.song.title + (root.song.artist && root.song.artist.length > 0 ? " · " + root.song.artist : "")) : ""
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
    elide: Text.ElideRight
    maximumLineCount: 1
  }

  Icon {
    id: icon

    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: Math.round(8 * Theme.scale)
    name: "music"
    color: Mpd.state === "play" ? Theme.green : Theme.subtext
    font.pixelSize: Theme.iconSizeLarge
  }
}
