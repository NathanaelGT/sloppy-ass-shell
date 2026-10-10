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
  visible: Osd.visible && Hypr.focusedScreenName === screenId

  anchors {
    bottom: true
    left: true
    right: true
  }
  margins.bottom: Math.round(16 * Theme.scale)

  implicitHeight: Math.round(58 * Theme.scale)
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  aboveWindows: true

  mask: Region {
    item: box
    radius: box.radius
  }

  Rectangle {
    id: box
    anchors.centerIn: parent
    width: row.implicitWidth + Math.round(40 * Theme.scale)
    height: Math.round(58 * Theme.scale)
    radius: height / 2
    color: Theme.mantle

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Math.round(12 * Theme.scale)

      Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Osd.icon
        font.pixelSize: Math.round(24 * Theme.scale)
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Osd.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(16 * Theme.scale)
        font.bold: true
      }

      Rectangle {
        visible: Osd.value >= 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(160 * Theme.scale)
        height: Math.round(8 * Theme.scale)
        radius: height / 2
        color: Theme.surfaceHigh

        Rectangle {
          width: Math.max(0, Math.min(1, Osd.value)) * parent.width
          height: parent.height
          radius: parent.radius
          color: Theme.primary
        }
      }
    }
  }
}
