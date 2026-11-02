import QtQuick
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen
  property real merge: 1
  property bool merged: false
  property string bannerIcon: ""
  property string lastBannerIcon: ""
  property real bannerIconLeft: -1
  property real bannerIconDrop: 0
  property real bannerIconDock: 0

  readonly property bool merging: root.merge > 0 && root.merge < 1
  readonly property real seal: root.smoothstep((root.merge - 0.65) / 0.35)
  readonly property real bannerIconRestLeft: (root.width - face.width) / 2
  readonly property real bannerIconDockLeft: root.bannerIconLeft >= 0 ? root.bannerIconLeft : root.bannerIconRestLeft
  readonly property real bannerIconOffset: (root.bannerIconDockLeft - root.bannerIconRestLeft) * root.bannerIconDock

  fill: root.merged ? Qt.rgba(Theme.capsuleFill.r, Theme.capsuleFill.g, Theme.capsuleFill.b, 0) : Theme.capsuleFill
  hoverFill: root.merged ? "transparent" : Theme.capsuleHover
  active: Panels.openOn("notifications", root.screen.name)
  bottomLeftRadius: root.seal * root.radius
  bottomRightRadius: root.seal * root.radius

  onClicked: {
    if (Notifs.bannerVisible) {
      Notifs.acknowledgeBanner()
    }
    Panels.toggle("notifications", root.screen.name)
  }
  onRightClicked: Notifs.dnd = !Notifs.dnd
  onMiddleClicked: Notifs.dismissAll()
  onBannerIconChanged: {
    if (root.bannerIcon !== "") {
      root.lastBannerIcon = root.bannerIcon
    }
  }

  readonly property int count: {
    const list = Notifs.active
    return list && typeof list.length === "number" ? list.length : 0
  }

  readonly property int unread: NotifStore.unreadCount

  readonly property int arrivals: Notifs.arrivals

  onArrivalsChanged: shakeAnim.restart()

  Component.onCompleted: root.merge = root.active ? 0 : 1

  onActiveChanged: {
    if (!root.active) {
      return
    }
    mergeAnim.stop()
    mergeAnim.to = 0
    mergeAnim.start()
  }

  Connections {
    target: Panels

    function onCloseCleared(name, screen) {
      if (name === "notifications" && screen === root.screen.name) {
        mergeAnim.stop()
        mergeAnim.to = 1
        mergeAnim.start()
      }
    }
  }

  function smoothstep(value) {
    const t = Math.max(0, Math.min(1, value))
    return t * t * (3 - 2 * t)
  }

  Behavior on bannerIconDrop {
    NumberAnimation {
      duration: 320
      easing.type: Easing.OutCubic
    }
  }

  Connections {
    target: Notifs

    function onBannerPhaseChanged() {
      const phase = Notifs.bannerPhase
      if (phase === "compact" || phase === "expanded") {
        glyphShowAnim.stop()
        iconHideAnim.stop()
        badgeShowAnim.stop()
        dockOutAnim.stop()
        glyphHideAnim.restart()
        iconShowAnim.restart()
        badgeHideAnim.restart()
        dockInAnim.restart()
        return
      }
      dockInAnim.stop()
      dockOutAnim.restart()
      if (phase === "hidden") {
        glyphHideAnim.stop()
        iconShowAnim.stop()
        badgeHideAnim.stop()
        glyphShowAnim.restart()
        iconHideAnim.restart()
        badgeShowAnim.restart()
      }
    }
  }

  NumberAnimation {
    id: glyphHideAnim

    target: bell
    property: "opacity"
    to: 0
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: glyphShowAnim

    target: bell
    property: "opacity"
    to: 1
    duration: 280
    easing.type: Easing.InOutSine
  }

  NumberAnimation {
    id: iconShowAnim

    target: appIcon
    property: "opacity"
    to: 1
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: iconHideAnim

    target: appIcon
    property: "opacity"
    to: 0
    duration: 280
    easing.type: Easing.InOutSine
  }

  NumberAnimation {
    id: badgeHideAnim

    target: badgeRect
    property: "opacity"
    to: 0
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: badgeShowAnim

    target: badgeRect
    property: "opacity"
    to: 1
    duration: 280
    easing.type: Easing.InOutSine
  }

  NumberAnimation {
    id: dockInAnim

    target: root
    property: "bannerIconDock"
    to: 1
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: dockOutAnim

    target: root
    property: "bannerIconDock"
    to: 0
    duration: 320
    easing.type: Easing.OutCubic
  }

  Item {
    id: face

    anchors.centerIn: parent
    width: Theme.bannerIconSize
    height: width

    Icon {
      id: bell

      anchors.centerIn: parent
      visible: opacity > 0
      name: Notifs.dnd ? "bell-off" : root.count > 0 ? "bell-ringing" : "bell"
      color: root.count > 0 ? Theme.primary : Theme.text
      font.pixelSize: Theme.iconSizeLarge
    }

    Image {
      id: appIcon

      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.bannerIconOffset
      anchors.verticalCenterOffset: root.bannerIconDrop
      opacity: 0
      visible: opacity > 0
      width: parent.width
      height: parent.height
      sourceSize: Qt.size(width, height)
      source: root.bannerIcon !== "" ? root.bannerIcon : root.lastBannerIcon
    }
  }

  NumberAnimation {
    id: mergeAnim

    target: root
    property: "merge"
    duration: 150
    easing.type: Easing.OutCubic
  }

  SequentialAnimation {
    id: shakeAnim

    NumberAnimation {
      target: face
      property: "rotation"
      to: -13
      duration: 60
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: face
      property: "rotation"
      to: 11
      duration: 90
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: face
      property: "rotation"
      to: -8
      duration: 90
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: face
      property: "rotation"
      to: 5
      duration: 85
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: face
      property: "rotation"
      to: -2
      duration: 75
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: face
      property: "rotation"
      to: 0
      duration: 60
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    id: badgeRect

    visible: root.unread > 0
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Math.round(4 * Theme.scale)
    width: Math.max(Math.round(16 * Theme.scale), badge.implicitWidth + Math.round(8 * Theme.scale))
    height: Math.round(16 * Theme.scale)
    radius: height / 2
    color: Theme.red

    Text {
      id: badge
      anchors.centerIn: parent
      text: root.unread
      color: Theme.crust
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      font.bold: true
    }
  }
}
