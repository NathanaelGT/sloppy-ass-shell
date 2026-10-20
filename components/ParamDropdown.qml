pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import "../services"

Rectangle {
  id: root

  property var candidates: []
  property int currentIndex: -1
  property string currentValue: ""
  property int maxHeight: Theme.dropdownRowHeight * 8

  signal activated(int index)

  function reveal(index) {
    if (index < 0) {
      return
    }
    const rowHeight = Theme.dropdownRowHeight
    const top = index * rowHeight
    const bottom = top + rowHeight
    if (top < flick.contentY) {
      flick.contentY = top
    } else if (bottom > flick.contentY + flick.height) {
      flick.contentY = bottom - flick.height
    }
  }

  visible: false
  width: Theme.dropdownWidth
  height: Math.min(Math.max(column.implicitHeight + Math.round(8 * Theme.scale), Theme.dropdownRowHeight), maxHeight)
  color: Theme.surfaceHigh
  radius: Theme.rowRadius
  border.width: 1
  border.color: Theme.surfaceHigher
  antialiasing: true
  z: 100

  Flickable {
    id: flick

    anchors.fill: parent
    anchors.margins: Math.round(4 * Theme.scale)
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    clip: true

    Column {
      id: column

      width: flick.width
      spacing: Math.round(1 * Theme.scale)

      Repeater {
        model: root.candidates

        delegate: Item {
          id: optionRow

          required property var modelData
          required property int index

          width: column.width
          height: Theme.dropdownRowHeight

          Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius
            color: optionRow.index === root.currentIndex ? Theme.surfaceHigher : "transparent"
            antialiasing: true
          }

          Icon {
            id: optionCheck

            anchors.left: parent.left
            anchors.leftMargin: Math.round(6 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(14 * Theme.scale)
            height: width
            visible: Providers.valueOf(optionRow.modelData) === root.currentValue

            name: "check"
            color: Theme.primary
            font.pixelSize: Math.round(11 * Theme.scale)
          }

          Text {
            anchors.left: optionCheck.right
            anchors.leftMargin: Math.round(4 * Theme.scale)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: Providers.labelOf(optionRow.modelData)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.activated(optionRow.index)
          }
        }
      }
    }
  }
}
