import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelWindow {
  id: root

  required property var modelData

  readonly property string screenId: modelData ? modelData.name : ""

  screen: modelData
  color: "transparent"
  visible: Hypr.focusedScreenName === screenId && recent.length > 0

  anchors {
    top: true
    right: true
  }
  margins.top: Theme.barThickness + Math.round(16 * Theme.scale)
  margins.right: Math.round(16 * Theme.scale)

  implicitWidth: Math.round(480 * Theme.scale)
  implicitHeight: list.implicitHeight
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  aboveWindows: true

  property var recent: []

  function push(notification) {
    if (Notifs.dnd) {
      return
    }
    const next = [notification]
    for (let i = 0; i < recent.length; i++) {
      if (recent[i] !== notification && next.length < 4) {
        next.push(recent[i])
      }
    }
    recent = next
  }

  function remove(notification) {
    recent = recent.filter(n => n !== notification)
  }

  Connections {
    target: Notifs.server
    function onNotification(notification) {
      root.push(notification)
    }
  }

  Column {
    id: list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Math.round(8 * Theme.scale)

    Repeater {
      model: root.recent

      delegate: Rectangle {
        id: toast

        required property var modelData

        width: list.width
        height: Math.max(Math.round(64 * Theme.scale), bodyText.implicitHeight + Math.round(36 * Theme.scale))
        radius: Math.round(14 * Theme.scale)
        color: Theme.mantle

        Timer {
          interval: 5000
          running: true
          onTriggered: root.remove(toast.modelData)
        }

        Connections {
          target: toast.modelData
          function onClosed(reason) {
            root.remove(toast.modelData)
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          onClicked: {
            toast.modelData.dismiss()
            root.remove(toast.modelData)
          }
        }

        Row {
          anchors.fill: parent
          anchors.margins: Math.round(12 * Theme.scale)
          spacing: Math.round(12 * Theme.scale)

          Image {
            anchors.top: parent.top
            width: Math.round(28 * Theme.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: Quickshell.iconPath(toast.modelData.appIcon, "dialog-information")
          }

          Column {
            width: parent.width - Math.round(70 * Theme.scale)
            spacing: Math.round(2 * Theme.scale)

            Text {
              width: parent.width
              text: toast.modelData.appName
              color: Theme.primary
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              elide: Text.ElideRight
            }

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
              visible: text.length > 0
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
            implicitWidth: Math.round(26 * Theme.scale)
            implicitHeight: Math.round(26 * Theme.scale)
            onClicked: {
              toast.modelData.dismiss()
              root.remove(toast.modelData)
            }
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
}
