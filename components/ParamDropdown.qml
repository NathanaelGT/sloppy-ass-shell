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
  property int codeWidth: 0

  signal activated(int index)

  readonly property int codeColumnWidth: root.codeWidth > 0 ? Math.ceil(codeRuler.implicitWidth) : 0

  function optionText(item) {
    const name = Providers.nameOf(item)
    return name.length > 0 ? " - " + name : ""
  }

  function aligned(item) {
    if (root.codeColumnWidth <= 0) {
      return false
    }
    return Providers.nameOf(item).length > 0
  }

  function codeRulerText() {
    const lines = ["0".repeat(root.codeWidth)]
    for (let i = 0; i < root.candidates.length; i++) {
      if (Providers.nameOf(root.candidates[i]).length === 0) {
        continue
      }
      lines.push(Providers.valueOf(root.candidates[i]))
    }
    return lines.join("\n")
  }

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

  Text {
    id: codeRuler

    visible: false
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
    text: root.codeRulerText()
  }

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

          readonly property bool selected: Providers.valueOf(optionRow.modelData) === root.currentValue

          width: column.width
          height: Theme.dropdownRowHeight

          Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius
            color: optionRow.index === root.currentIndex ? Theme.surfaceHigher : (optionRow.selected ? Theme.dropdownValueFill : "transparent")
            antialiasing: true
          }

          Text {
            id: optionCode

            anchors.left: parent.left
            anchors.leftMargin: Math.round(10 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: root.codeColumnWidth
            visible: root.aligned(optionRow.modelData)
            horizontalAlignment: Text.AlignRight
            text: Providers.valueOf(optionRow.modelData)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          Text {
            anchors.left: optionCode.visible ? optionCode.right : parent.left
            anchors.leftMargin: optionCode.visible ? 0 : Math.round(10 * Theme.scale)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            text: optionCode.visible ? root.optionText(optionRow.modelData) : Providers.labelOf(optionRow.modelData)
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
