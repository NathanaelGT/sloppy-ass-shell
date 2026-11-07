import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

Item {
  id: root

  required property var modelData

  readonly property var entry: modelData.entry
  readonly property int depth: modelData.depth
  readonly property bool expanded: modelData.expanded
  readonly property bool separator: entry.isSeparator
  readonly property bool submenu: entry.hasChildren
  readonly property bool active: entry.enabled
  readonly property bool checkable: entry.buttonType !== QsMenuButtonType.None
  readonly property bool checked: entry.checkState === Qt.Checked
  readonly property bool partial: entry.checkState === Qt.PartiallyChecked

  signal expandToggled(var entry)

  readonly property int rowH: Math.round(24 * Theme.scale)
  readonly property int padX: Math.round(8 * Theme.scale)
  readonly property int indent: Math.round(14 * Theme.scale)
  readonly property int slotW: Math.round(15 * Theme.scale)
  readonly property int textGap: Math.round(8 * Theme.scale)
  readonly property string displayText: root.separator ? "" : String(entry.text).replace(/&(.)/g, "$1")

  width: parent.width
  height: root.separator ? Math.round(9 * Theme.scale) : root.rowH

  function state() {
    return {
      depth: root.depth,
      text: root.displayText,
      separator: root.separator,
      enabled: root.active,
      buttonType: root.entry.buttonType === QsMenuButtonType.CheckBox ? "checkbox" : root.entry.buttonType === QsMenuButtonType.RadioButton ? "radio" : "none",
      checkState: root.entry.checkState === Qt.Checked ? "checked" : root.entry.checkState === Qt.PartiallyChecked ? "partial" : "unchecked",
      hasChildren: root.submenu,
      expanded: root.expanded
    }
  }

  function invoke() {
    if (root.separator || !root.active) {
      return "disabled"
    }
    if (root.submenu) {
      root.expandToggled(root.entry)
      return "submenu"
    }
    Panels.close()
    root.entry.triggered()
    return "done"
  }

  Rectangle {
    anchors.fill: parent
    visible: !root.separator
    radius: Theme.rowRadius
    color: root.active && rowMouse.containsMouse ? Theme.surface : "transparent"
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 1
    visible: root.separator
    color: Theme.surfaceHigher
  }

  Item {
    id: checkSlot

    x: root.padX + root.depth * root.indent
    anchors.verticalCenter: parent.verticalCenter
    width: root.slotW
    height: root.slotW
    visible: root.checkable

    Rectangle {
      anchors.centerIn: parent
      visible: !root.partial
      width: Math.round(12 * Theme.scale)
      height: width
      radius: root.entry.buttonType === QsMenuButtonType.RadioButton ? width / 2 : Math.round(4 * Theme.scale)
      color: root.checked ? Theme.primary : "transparent"
      border.width: 1
      border.color: root.checked ? Theme.primary : Theme.surfaceHigher

      Icon {
        anchors.centerIn: parent
        visible: root.checked && root.entry.buttonType === QsMenuButtonType.CheckBox
        name: "check"
        color: Theme.onAccent
        font.pixelSize: Math.round(9 * Theme.scale)
      }

      Rectangle {
        anchors.centerIn: parent
        visible: root.checked && root.entry.buttonType === QsMenuButtonType.RadioButton
        width: Math.round(4 * Theme.scale)
        height: width
        radius: width / 2
        color: Theme.onAccent
      }
    }

    Rectangle {
      anchors.centerIn: parent
      visible: root.partial
      width: Math.round(12 * Theme.scale)
      height: width
      radius: Math.round(4 * Theme.scale)
      color: Theme.primary

      Icon {
        anchors.centerIn: parent
        name: "minus"
        color: Theme.onAccent
        font.pixelSize: Math.round(9 * Theme.scale)
      }
    }
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: root.padX + root.depth * root.indent + root.slotW + root.textGap
    anchors.right: parent.right
    anchors.rightMargin: root.submenu ? Math.round(22 * Theme.scale) : root.padX
    anchors.verticalCenter: parent.verticalCenter
    visible: !root.separator
    text: root.displayText
    color: root.active ? Theme.text : Theme.overlay
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    elide: Text.ElideRight
  }

  Icon {
    anchors.right: parent.right
    anchors.rightMargin: root.padX
    anchors.verticalCenter: parent.verticalCenter
    visible: root.submenu
    name: root.expanded ? "chevron-down" : "chevron-right"
    color: Theme.subtext
    font.pixelSize: Math.round(13 * Theme.scale)
  }

  MouseArea {
    id: rowMouse

    anchors.fill: parent
    enabled: root.active
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.invoke()
  }
}
