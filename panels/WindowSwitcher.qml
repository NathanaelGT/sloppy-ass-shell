import QtQuick
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "window-switcher"
  align: "center"
  vertical: "center"
  attached: false
  cardWidth: Math.round(420 * Theme.scale)
  exclusiveFocus: true

  readonly property var items: {
    const monitor = Hypr.monitor;
    if (!monitor) return [];
    const workspace = monitor.activeWorkspace;
    if (!workspace || !workspace.toplevels) return [];
    const list = workspace.toplevels;
    return list.values ? list.values : list;
  }

  readonly property int selected: 0

  function activate(index) {
    const item = items[index];
    if (!item) return;
    Panels.close();
    Hypr.focusToplevel(item.address);
  }

  onKeyPressed: (event) => {
    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) root.activate(event.key - Qt.Key_1);
  }

  Column {
    id: list

    width: parent.width
    spacing: Math.round(4 * Theme.scale)

    Repeater {
      model: root.items

      delegate: Rectangle {
        id: entry

        required property var modelData
        required property int index

        width: parent.width
        height: Math.round(38 * Theme.scale)
        radius: Math.round(10 * Theme.scale)
        color: entryMouse.containsMouse ? Theme.surface : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Math.round(12 * Theme.scale)
          anchors.right: shortcut.left
          anchors.rightMargin: Math.round(8 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          text: entry.modelData.title
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }

        Text {
          id: shortcut
          anchors.right: parent.right
          anchors.rightMargin: Math.round(12 * Theme.scale)
          anchors.verticalCenter: parent.verticalCenter
          text: entry.index + 1
          color: Theme.overlay
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }

        MouseArea {
          id: entryMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.activate(entry.index)
        }
      }
    }
  }
}
