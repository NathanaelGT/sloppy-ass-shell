import QtQuick
import Quickshell
import "../../theme"
import "../../components"
import "../../services"

Item {
  id: root

  property var screen

  implicitHeight: Theme.capsuleThickness
  implicitWidth: row.implicitWidth
  height: implicitHeight
  width: implicitWidth

  readonly property var spaces: {
    const all = Hypr.workspaces;
    const result = [];
    if (!all) return result;
    for (let i = 0; i < all.length; i++) {
      const ws = all[i];
      if (ws.monitor && ws.monitor.name === root.screen.name) result.push(ws);
    }
    result.sort((a, b) => a.id - b.id);
    return result;
  }

  function appsOf(workspace) {
    const list = workspace.toplevels;
    if (!list) return [];
    return list.values ? list.values : list;
  }

  function classOf(toplevel) {
    if (!toplevel) return "";
    if (toplevel.wayland && toplevel.wayland.appId) return toplevel.wayland.appId;
    const ipc = toplevel.lastIpcObject;
    if (!ipc) return "";
    return ipc.class || ipc.initialClass || "";
  }

  function iconName(toplevel) {
    return AppIcons.resolve(root.classOf(toplevel));
  }

  Row {
    id: row
    spacing: Math.round(4 * Theme.scale)

    Repeater {
      model: root.spaces

      delegate: BarButton {
        id: pill

        required property var modelData
        readonly property var space: modelData

        implicitWidth: content.implicitWidth + Math.round(18 * Theme.scale)
        borderWidth: Math.round(1 * Theme.scale)
        borderColor: pill.space.active ? Theme.primary : Theme.capsuleBorder
        onClicked: Hypr.focusWorkspace(space.id)
        onRightClicked: Panels.toggle("window-switcher", root.screen.name)

        Row {
          id: content
          anchors.centerIn: parent
          spacing: Math.round(4 * Theme.scale)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.space.id
            color: pill.space.active ? Theme.primary : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: pill.space.active
          }

          Repeater {
            model: root.appsOf(pill.space)

            delegate: Image {
              id: appIcon

              required property var modelData

              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(18 * Theme.scale)
              height: width
              sourceSize: Qt.size(width, height)
              source: Quickshell.iconPath(root.iconName(appIcon.modelData), "application-x-executable")

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (e) => {
                  if (e.button === Qt.RightButton) Panels.toggle("window-switcher", root.screen.name);
                  else Hypr.focusToplevel(appIcon.modelData.address);
                }
              }
            }
          }
        }
      }
    }
  }
}
