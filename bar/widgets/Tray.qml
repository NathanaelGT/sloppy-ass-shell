import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../theme"
import "../../components"

BarButton {
  id: root

  property var screen

  implicitWidth: content.implicitWidth + Math.round(18 * Theme.scale)
  borderWidth: Math.round(1 * Theme.scale)
  borderColor: Theme.capsuleBorder
  visible: content.implicitWidth > 0

  Row {
    id: content

    anchors.centerIn: parent
    spacing: Math.round(6 * Theme.scale)

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: trayItem

        required property var modelData

        visible: modelData.status !== Status.Passive
        width: Math.round(18 * Theme.scale)
        height: width
        anchors.verticalCenter: parent.verticalCenter

        Image {
          id: trayIcon

          anchors.fill: parent
          sourceSize: Qt.size(width, height)
          source: trayItem.modelData.icon
          onStatusChanged: {
            if (status === Image.Error) source = Quickshell.iconPath("application-x-executable", "");
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: (event) => {
            if (event.button === Qt.RightButton) {
              if (trayItem.modelData.hasMenu) trayItem.modelData.display(Window.window, trayItem.width / 2, trayItem.height);
              else trayItem.modelData.secondaryActivate();
            } else if (event.button === Qt.MiddleButton) {
              trayItem.modelData.secondaryActivate();
            } else if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
              trayItem.modelData.display(Window.window, trayItem.width / 2, trayItem.height);
            } else {
              trayItem.modelData.activate();
            }
          }
          onWheel: (event) => trayItem.modelData.scroll(event.angleDelta.y, false)
        }
      }
    }
  }
}
