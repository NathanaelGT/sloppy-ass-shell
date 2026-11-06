import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen
  property int hoverCount: 0

  readonly property var spaces: {
    const all = Hypr.workspaces
    const result = []
    if (!all) {
      return result
    }
    for (let i = 0; i < all.length; i++) {
      const ws = all[i]
      if (ws.monitor && ws.monitor.name === root.screen.name) {
        result.push(ws)
      }
    }
    result.sort((a, b) => {
      const groupA = root.isSpecial(a) ? 1 : 0
      const groupB = root.isSpecial(b) ? 1 : 0
      if (groupA !== groupB) {
        return groupA - groupB
      }
      return a.id - b.id
    })
    return result
  }

  readonly property var monitor: Hypr.monitorFor(root.screen)
  readonly property string focusedAddress: Hypr.activeWindowAddress
  readonly property int activeWsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  readonly property string shownSpecial: {
    const info = monitor && monitor.lastIpcObject ? monitor.lastIpcObject.specialWorkspace : null
    return info && info.name ? info.name : ""
  }

  implicitHeight: Theme.capsuleThickness
  implicitWidth: content.implicitWidth + Math.round(20 * Theme.scale)
  height: implicitHeight
  width: implicitWidth
  borderWidth: Math.round(1 * Theme.scale)
  borderColor: Theme.capsuleBorder
  fill: hoverCount > 0 ? Theme.capsuleHover : Theme.capsuleFill

  onActiveWsIdChanged: Qt.callLater(placeUnderline)
  onShownSpecialChanged: Qt.callLater(placeUnderline)
  onFocusedAddressChanged: Qt.callLater(placeUnderline)
  onSpacesChanged: Qt.callLater(placeUnderline)
  onWidthChanged: Qt.callLater(placeUnderline)

  function appsOf(workspace) {
    const list = workspace.toplevels
    if (!list) {
      return []
    }
    return list.values ? list.values : list
  }

  function classOf(toplevel) {
    if (!toplevel) {
      return ""
    }
    if (toplevel.wayland && toplevel.wayland.appId) {
      return toplevel.wayland.appId
    }
    const ipc = toplevel.lastIpcObject
    if (!ipc) {
      return ""
    }
    return ipc.class || ipc.initialClass || ""
  }

  function iconName(toplevel) {
    return AppIcons.resolve(root.classOf(toplevel))
  }

  function isSpecial(space) {
    return space.name.indexOf("special:") === 0
  }

  function isShown(space) {
    if (root.isSpecial(space)) {
      return root.shownSpecial === space.name
    }
    return space.id === root.activeWsId
  }

  function labelOf(space) {
    if (root.isSpecial(space)) {
      return "S"
    }
    return String(space.id)
  }

  function cycleWindows(space, delta) {
    const list = appsOf(space)
    const count = list.length
    if (count < 2) {
      return
    }
    const addr = root.focusedAddress
    let idx = -1
    for (let i = 0; i < count; i++) {
      if (list[i].address === addr) {
        idx = i
        break
      }
    }
    const next = ((idx < 0 ? 0 : idx) + (delta > 0 ? 1 : count - 1)) % count
    Hypr.focusToplevel(list[next].address)
  }

  function placeUnderline() {
    let target = null
    for (let i = 0; i < root.spaces.length; i++) {
      const group = groupRepeater.itemAt(i)
      if (!group) {
        continue
      }
      target = group.focusIcon()
      if (target) {
        break
      }
    }
    if (!target) {
      underline.opacity = 0
      return
    }
    underline.targetX = target.mapToItem(root, 0, 0).x + (target.width - underline.width) / 2
    underline.opacity = 1
  }

  Component.onCompleted: Qt.callLater(placeUnderline)

  Row {
    id: content

    anchors.centerIn: parent
    spacing: 0

    Repeater {
      id: groupRepeater

      model: root.spaces

      delegate: Item {
        id: group

        required property int index
        required property var modelData
        readonly property var space: modelData
        readonly property bool last: index === root.spaces.length - 1

        implicitWidth: inner.implicitWidth + (last ? 0 : Math.round(13 * Theme.scale))
        height: Theme.capsuleThickness

        function focusIcon() {
          for (let i = 0; i < iconRepeater.count; i++) {
            const icon = iconRepeater.itemAt(i)
            if (icon && icon.address === root.focusedAddress) {
              return icon
            }
          }
          return null
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: e => {
            if (e.button === Qt.RightButton) {
              Panels.toggle("window-switcher", root.screen.name)
            } else if (root.isSpecial(group.space)) {
              Hypr.toggleSpecial(group.space.name)
            } else {
              Hypr.focusWorkspace(group.space.id)
            }
          }
          onWheel: e => root.cycleWindows(group.space, e.angleDelta.y)
          onEntered: root.hoverCount++
          onExited: root.hoverCount--
        }

        Row {
          id: inner

          anchors.verticalCenter: parent.verticalCenter
          spacing: Math.round(3 * Theme.scale)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelOf(group.space)
            color: root.isShown(group.space) ? Theme.primary : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: root.isShown(group.space)
            rightPadding: Math.round(1 * Theme.scale)
          }

          Repeater {
            id: iconRepeater

            model: root.appsOf(group.space)

            delegate: Item {
              id: appIcon

              required property var modelData
              readonly property string address: modelData.address ?? ""

              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(18 * Theme.scale)
              height: width

              Image {
                anchors.fill: parent
                sourceSize: Qt.size(width, height)
                source: Quickshell.iconPath(root.iconName(appIcon.modelData), "application-x-executable")
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                  if (e.button === Qt.RightButton) {
                    Panels.toggle("window-switcher", root.screen.name)
                  } else if (root.isSpecial(group.space) && root.isShown(group.space)) {
                    Hypr.toggleSpecial(group.space.name)
                  } else {
                    Hypr.focusToplevel(appIcon.address)
                  }
                }
              }
            }
          }
        }

        Rectangle {
          visible: !group.last
          x: inner.implicitWidth + Math.round(6 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(1 * Theme.scale)
          height: Math.round(14 * Theme.scale)
          radius: width / 2
          color: Theme.surfaceHigher
        }
      }
    }
  }

  Rectangle {
    id: underline

    property real targetX: 0

    visible: opacity > 0.01
    opacity: 0
    x: targetX
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(3 * Theme.scale)
    width: Math.round(18 * Theme.scale)
    height: Math.round(2 * Theme.scale)
    radius: height / 2
    color: Theme.primary

    Behavior on x {
      enabled: underline.opacity > 0.01
      NumberAnimation {
        duration: 120
        easing.type: Easing.OutCubic
      }
    }

    Behavior on opacity {
      NumberAnimation {
        duration: 150
      }
    }
  }
}
