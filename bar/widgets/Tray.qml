import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../theme"
import "../../components"
import "../../services"

BarButton {
  id: root

  property var screen

  readonly property var items: {
    const all = SystemTray.items
    const result = []
    if (!all) {
      return result
    }
    const values = all.values
    for (let i = 0; i < values.length; i++) {
      const item = values[i]
      if (item.status !== Status.Passive) {
        result.push(item)
      }
    }
    return result
  }

  implicitWidth: content.implicitWidth + Math.round(18 * Theme.scale)
  borderWidth: Math.round(1 * Theme.scale)
  borderColor: Theme.capsuleBorder
  fill: Theme.capsuleFill
  hoverFill: Theme.capsuleFill
  visible: content.implicitWidth > 0

  function openMenu(item, host) {
    const point = host.mapToItem(null, host.width / 2, host.height)
    Panels.openTray(item, Math.round(point.x), root.screen.name)
  }

  Row {
    id: content

    anchors.centerIn: parent
    spacing: 0

    Repeater {
      model: root.items

      delegate: Item {
        id: trayItem

        required property int index
        required property var modelData

        readonly property bool last: index === root.items.length - 1

        width: icon.width + (trayItem.last ? 0 : Math.round(13 * Theme.scale))
        height: Theme.capsuleThickness

        Item {
          id: icon

          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(18 * Theme.scale)
          height: width

          HoverPill {
            id: iconPill

            hovered: trayArea.containsMouse
          }

          Image {
            id: trayIcon

            anchors.fill: parent
            sourceSize: Qt.size(width, height)
            source: trayItem.modelData.icon
            onStatusChanged: {
              if (status === Image.Error) {
                source = Quickshell.iconPath("application-x-executable", "")
              }
            }
          }

          MouseArea {
            id: trayArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: event => {
              if (event.button === Qt.RightButton) {
                if (trayItem.modelData.hasMenu) {
                  root.openMenu(trayItem.modelData, trayIcon)
                } else {
                  trayItem.modelData.activate()
                }
              } else if (event.button === Qt.MiddleButton) {
                trayItem.modelData.secondaryActivate()
              } else if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                root.openMenu(trayItem.modelData, trayIcon)
              } else {
                trayItem.modelData.activate()
              }
            }
            onWheel: event => trayItem.modelData.scroll(event.angleDelta.y, false)
          }
        }

        Rectangle {
          visible: !trayItem.last
          x: icon.width + Math.round(6 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(1 * Theme.scale)
          height: Math.round(14 * Theme.scale)
          radius: width / 2
          color: Theme.surfaceHigher
        }
      }
    }
  }
}
