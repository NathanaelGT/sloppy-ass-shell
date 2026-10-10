import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "session"
  align: "center"
  vertical: "center"
  attached: false
  cardWidth: Math.round(360 * Theme.scale)
  exclusiveFocus: true

  readonly property var actions: [
    { icon: "lock", label: "Lock", shortcut: "1", command: ["hyprlock"] },
    { icon: "suspend", label: "Lock & Suspend", shortcut: "2", command: ["bash", "-lc", "loginctl lock-session; systemctl suspend"] },
    { icon: "restart", label: "Reboot", shortcut: "3", command: ["bash", "-lc", "hyprshutdown -p 'setterm --blank force && systemctl reboot'"] },
    { icon: "shutdown", label: "Shutdown", shortcut: "4", command: ["bash", "-lc", "hyprshutdown -p 'setterm --blank force && systemctl poweroff'"] }
  ]

  function run(index) {
    const action = actions[index];
    if (!action) return;
    Panels.close();
    Quickshell.execDetached(action.command);
  }

  onKeyPressed: (event) => {
    if (event.key === Qt.Key_1) root.run(0);
    else if (event.key === Qt.Key_2) root.run(1);
    else if (event.key === Qt.Key_3) root.run(2);
    else if (event.key === Qt.Key_4) root.run(3);
  }

  Item {
    width: parent.width
    height: content.height

    Grid {
      id: content

      anchors.horizontalCenter: parent.horizontalCenter
      columns: 2
      spacing: Math.round(12 * Theme.scale)

      Repeater {
        model: root.actions

        delegate: Tile {
          id: sessionTile

          required property var modelData
          required property int index

          width: Math.round(150 * Theme.scale)
          icon: modelData.icon
          label: modelData.label + "  (" + modelData.shortcut + ")"
          active: false
          onClicked: root.run(sessionTile.index)
        }
      }
    }
  }
}
