import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "notifications"

  readonly property var items: {
    const list = Notifs.active;
    if (!list) return [];
    const out = [];
    for (let i = 0; i < list.length; i++) out.push(list[i]);
    return out;
  }

  PanelHeader {
    title: "Notifications"

    BarButton {
      capsule: false
      implicitWidth: Math.round(28 * Theme.scale)
      implicitHeight: Math.round(28 * Theme.scale)
      visible: Notifs.dnd || root.items.length > 0
      hoverFill: Theme.surfaceHigh
      onClicked: {
        if (root.items.length > 0) Notifs.dismissAll();
        else Notifs.dnd = false;
      }
      Icon {
        anchors.centerIn: parent
        name: "trash"
        font.pixelSize: Theme.fontSize
      }
    }
  }

  Text {
    visible: root.items.length === 0 && !Notifs.dnd
    width: parent.width
    text: "No notifications"
    color: Theme.overlay
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignHCenter
  }

  Text {
    visible: Notifs.dnd
    width: parent.width
    text: "Silenced"
    color: Theme.yellow
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
    horizontalAlignment: Text.AlignHCenter
  }

  Repeater {
    model: root.items

    delegate: Rectangle {
      id: toast

      required property var modelData

      width: root.contentWidth
      height: Math.max(Math.round(50 * Theme.scale), bodyText.implicitHeight + Math.round(30 * Theme.scale))
      radius: Math.round(12 * Theme.scale)
      color: Theme.surface
      antialiasing: true

      Row {
        anchors.fill: parent
        anchors.margins: Math.round(10 * Theme.scale)
        spacing: Math.round(10 * Theme.scale)

        Image {
          anchors.top: parent.top
          width: Math.round(22 * Theme.scale)
          height: width
          sourceSize: Qt.size(width, height)
          source: Quickshell.iconPath(toast.modelData.appIcon, "dialog-information")
        }

        Column {
          width: parent.width - Math.round(50 * Theme.scale)
          spacing: Math.round(2 * Theme.scale)

          Text {
            width: parent.width
            text: toast.modelData.summary
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            id: bodyText
            width: parent.width
            text: toast.modelData.body
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }
        }

        BarButton {
          capsule: false
          implicitWidth: Math.round(24 * Theme.scale)
          implicitHeight: Math.round(24 * Theme.scale)
          onClicked: toast.modelData.dismiss()
          Icon {
            anchors.centerIn: parent
            name: "x"
            font.pixelSize: Theme.fontSizeSmall
          }
        }
      }
    }
  }
}
