import QtQuick
import "../theme"

Item {
  id: root

  property string text: ""
  property color color: Theme.text
  property bool bold: false
  property bool editing: false

  signal edited(string value)

  readonly property string testDraft: input.text
  readonly property int testCursorPosition: input.cursorPosition

  function testSetText(value) {
    input.text = value;
  }

  function testPressAt(lx, ly) {
    input.deselect();
    input.cursorPosition = input.positionAt(lx, ly);
  }

  function testCommit() {
    root.commit();
  }

  function testCancel() {
    root.cancel();
  }

  implicitHeight: Math.round(20 * Theme.scale)

  function begin() {
    input.text = root.text;
    root.editing = true;
    input.forceActiveFocus();
    input.selectAll();
  }

  function commit() {
    root.edited(input.text.trim());
    root.editing = false;
    input.focus = false;
  }

  function cancel() {
    root.editing = false;
    input.focus = false;
  }

  Text {
    anchors.fill: parent
    visible: !root.editing
    text: root.text
    color: root.color
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: root.bold
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    visible: opacity > 0
    opacity: root.editing ? 1 : 0
    color: Theme.subtext
    antialiasing: true

    Behavior on opacity {
      NumberAnimation { duration: 100 }
    }
  }

  TextInput {
    id: input

    anchors.fill: parent
    visible: root.editing
    color: root.color
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: root.bold
    verticalAlignment: TextInput.AlignVCenter
    selectionColor: Theme.surfaceHigh
    clip: true
    onAccepted: root.commit()
    onActiveFocusChanged: {
      if (!activeFocus && root.editing) root.cancel();
    }
    Keys.onEscapePressed: root.cancel()
  }

  MouseArea {
    anchors.fill: parent
    enabled: !root.editing
    cursorShape: Qt.IBeamCursor
    onClicked: root.begin()
  }
}
