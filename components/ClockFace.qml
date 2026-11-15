import QtQuick
import "../theme"
import "../services"

Item {
  id: root

  readonly property real contentWidth: dateMetrics.advanceWidth + spaceMetrics.advanceWidth * 3 + timeSlotWidth + witaMetrics.width
  readonly property int timeSlotWidth: Math.max(Math.round(timeMetrics.advanceWidth), Math.round(spaceMetrics.advanceWidth))

  implicitWidth: contentWidth
  implicitHeight: row.implicitHeight

  TextMetrics {
    id: dateMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: ClockState.dateText
  }

  TextMetrics {
    id: timeMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "88:88:88"
  }

  TextMetrics {
    id: witaMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "WITA"
  }

  TextMetrics {
    id: spaceMetrics

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: " "
  }

  Row {
    id: row

    anchors.centerIn: parent
    spacing: spaceMetrics.advanceWidth

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ClockState.dateText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
      }

      Item {
        width: spaceMetrics.advanceWidth * 2
        height: 1
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.timeSlotWidth
        text: ClockState.timeText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: witaMetrics.width
      horizontalAlignment: Text.AlignHCenter
      text: ClockState.zoneText
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      verticalAlignment: Text.AlignVCenter
    }
  }
}
