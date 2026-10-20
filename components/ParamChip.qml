import QtQuick
import "../theme"

Rectangle {
  id: root

  property var param: null
  property var valueState: null
  property bool active: false
  property bool dropdown: false
  property bool syncing: false

  signal edited(string text)
  signal moveFocus(int direction)
  signal dismiss
  signal accept
  signal candidateStep(int direction)
  signal candidateAccept
  signal focusRequested
  signal queryRequested
  signal paramJump(int index)
  signal ready

  readonly property bool editorFocused: editor.activeFocus
  readonly property bool editorHasFocus: editor.focus

  function handleKey(key, modifiers) {
    if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
      root.moveFocus(modifiers & Qt.ShiftModifier ? -1 : 1)
      return true
    }
    if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      if (root.dropdown) {
        root.candidateAccept()
      }
      root.accept()
      return true
    }
    if (key === Qt.Key_Escape) {
      root.dismiss()
      return true
    }
    if (key === Qt.Key_Space && modifiers & Qt.ControlModifier) {
      root.queryRequested()
      return true
    }
    if (key >= Qt.Key_F1 && key <= Qt.Key_F8) {
      root.paramJump(key - Qt.Key_F1 + 1)
      return true
    }
    if ((key === Qt.Key_Up || key === Qt.Key_Down) && root.dropdown) {
      root.candidateStep(key === Qt.Key_Up ? -1 : 1)
      return true
    }
    return false
  }

  function isRequired() {
    return root.param && root.param.required === true
  }

  function isSet() {
    return root.valueState && root.valueState.set === true
  }

  function errorText() {
    return root.valueState && root.valueState.error ? root.valueState.error : ""
  }

  function hasError() {
    return root.errorText().length > 0
  }

  function stateText() {
    if (!root.valueState || root.valueState.text === undefined) {
      return ""
    }
    return String(root.valueState.text)
  }

  function displayText() {
    if (root.valueState && root.valueState.value !== undefined && root.valueState.value !== "") {
      return String(root.valueState.value)
    }
    if (root.hasError()) {
      return ""
    }
    return root.param && root.param.placeholder ? root.param.placeholder : "?"
  }

  function shownText() {
    if (root.active) {
      return root.stateText()
    }
    return root.displayText()
  }

  function syncShown() {
    const next = root.shownText()
    if (editor.text === next) {
      return
    }
    root.syncing = true
    editor.text = next
    root.syncing = false
  }

  function chipColor() {
    return Theme.surfaceHigh
  }

  function nameColor() {
    return Theme.subtext
  }

  function displayColor() {
    if (root.hasError()) {
      return Theme.red
    }
    if (root.isSet()) {
      return Theme.text
    }
    return Theme.subtext
  }

  function editorColor() {
    if (root.hasError()) {
      return Theme.red
    }
    return Theme.text
  }

  function activateEditor() {
    root.syncShown()
    editor.selectAll()
    Qt.callLater(function () {
      editor.forceActiveFocus()
      editor.selectAll()
    })
  }

  onActiveChanged: {
    root.syncShown()
    if (root.active) {
      root.activateEditor()
    }
  }

  onValueStateChanged: {
    root.syncShown()
  }

  width: content.width + Theme.chipPadX * 2
  height: Theme.chipHeight
  radius: Theme.chipRadius
  color: root.chipColor()
  border.width: root.active || root.editorFocused || root.editorHasFocus || root.hasError() ? 1 : 0
  border.color: root.hasError() ? Theme.red : Theme.primary
  antialiasing: true

  Item {
    id: content

    anchors.left: parent.left
    anchors.leftMargin: Theme.chipPadX
    anchors.verticalCenter: parent.verticalCenter
    width: nameLabel.implicitWidth + valueBody.width + (root.hasError() ? errorLabel.implicitWidth + Math.round(4 * Theme.scale) : 0)
    height: parent.height

    Text {
      id: nameLabel

      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: (root.param && root.param.label ? root.param.label : (root.param ? root.param.key : "")) + (root.isRequired() ? "*" : "") + ":"
      color: root.nameColor()
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
    }

    Item {
      id: valueBody

      anchors.left: nameLabel.right
      anchors.leftMargin: Math.round(3 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(editor.implicitWidth, placeholder.implicitWidth)
      height: parent.height

      Text {
        id: placeholder

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.active && editor.text.length === 0
        text: root.displayText()
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      TextInput {
        id: editor

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        focus: root.active
        color: root.active || root.editorFocused ? root.editorColor() : root.displayColor()
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        selectByMouse: true
        selectionColor: Theme.crust
        selectedTextColor: Theme.text

        onTextChanged: {
          if (!root.syncing) {
            root.edited(text)
          }
        }

        Keys.onPressed: event => {
          if (root.handleKey(event.key, event.modifiers)) {
            event.accepted = true
          }
        }
      }
    }

    Text {
      id: errorLabel

      anchors.left: valueBody.right
      anchors.leftMargin: Math.round(4 * Theme.scale)
      anchors.verticalCenter: parent.verticalCenter
      visible: root.hasError()
      text: root.errorText()
      color: Theme.red
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
    }
  }

  Component.onCompleted: {
    root.ready()
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.IBeamCursor
    onClicked: root.focusRequested()
  }
}
