import QtQuick
import "../theme"

Item {
  id: root

  property real percent: 0
  property real maximum: 150
  property bool editing: false

  readonly property color valueColor: Math.round(root.percent) >= 101 ? Theme.red : Theme.subtext

  signal edited(real percent)
  signal wheeled(real angleDelta)

  readonly property string testDraft: input.text
  readonly property int testCursorPosition: input.cursorPosition

  function testSetText(value) {
    input.text = value
  }

  function testPressAt(lx, ly) {
    input.deselect()
    input.cursorPosition = input.positionAt(lx - input.x, ly - input.y)
  }

  function testCommit() {
    root.commit()
  }

  function testCancel() {
    root.cancel()
  }

  implicitWidth: Math.round(32 * Theme.scale)
  implicitHeight: Math.round(16 * Theme.scale)

  function begin() {
    input.text = String(Math.round(root.percent))
    root.editing = true
    input.forceActiveFocus()
    input.selectAll()
  }

  function commit() {
    const value = parseFloat(input.text)
    if (!isNaN(value)) {
      root.edited(Math.max(0, Math.min(root.maximum, value)))
    }
    root.editing = false
    input.focus = false
  }

  function cancel() {
    root.editing = false
    input.focus = false
  }

  Text {
    id: suffix

    anchors.right: parent.right
    anchors.rightMargin: Math.round(4 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    text: "%"
    color: root.valueColor
    font.family: Theme.fontFamily
    font.pixelSize: Math.round(9 * Theme.scale)
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: Math.round(4 * Theme.scale)
    anchors.right: suffix.left
    anchors.rightMargin: Math.round(2 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    visible: !root.editing
    text: Math.round(root.percent)
    color: root.valueColor
    font.family: Theme.fontFamily
    font.pixelSize: Math.round(9 * Theme.scale)
    horizontalAlignment: Text.AlignRight
  }

  Rectangle {
    anchors.fill: parent
    visible: opacity > 0
    opacity: root.editing ? 1 : 0
    radius: Math.round(6 * Theme.scale)
    color: "transparent"
    border.width: 1
    border.color: Theme.subtext
    antialiasing: true

    Behavior on opacity {
      NumberAnimation {
        duration: 100
      }
    }
  }

  TextInput {
    id: input

    anchors.left: parent.left
    anchors.leftMargin: Math.round(4 * Theme.scale)
    anchors.right: suffix.left
    anchors.rightMargin: Math.round(2 * Theme.scale)
    anchors.verticalCenter: parent.verticalCenter
    visible: root.editing
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Math.round(9 * Theme.scale)
    horizontalAlignment: TextInput.AlignRight
    selectionColor: Theme.surfaceHigh
    inputMethodHints: Qt.ImhDigitsOnly
    onAccepted: root.commit()
    onActiveFocusChanged: {
      if (!activeFocus && root.editing) {
        root.cancel()
      }
    }
    Keys.onEscapePressed: root.cancel()
  }

  MouseArea {
    anchors.fill: parent
    enabled: !root.editing
    cursorShape: Qt.PointingHandCursor
    onClicked: root.begin()
    onWheel: e => {
      root.wheeled(e.angleDelta.y)
      e.accepted = true
    }
  }
}
