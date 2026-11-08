import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

Item {
  id: root

  property string screenName: ""
  property bool preview: false
  property bool shown: true

  readonly property bool acceptInput: root.preview || LockState.secure
  readonly property bool failed: LockState.attempts > 0
  readonly property color fieldBorder: root.failed ? Theme.red : Theme.surfaceHigher

  function testSetPassword(text) {
    field.text = text
  }

  function submitField() {
    if (!root.acceptInput) {
      return false
    }
    if (field.text === "") {
      return false
    }
    return LockState.submit(field.text)
  }

  readonly property int fieldLength: field.text.length

  onAcceptInputChanged: if (root.acceptInput) {
    field.forceActiveFocus()
  }

  Connections {
    target: LockState

    function onFieldTextChanged() {
      if (field.text !== LockState.fieldText) {
        field.text = LockState.fieldText
      }
    }
  }

  onShownChanged: {
    if (root.shown) {
      root.opacity = 0
      showAnim.restart()
      LockState.noteScreen(root)
    } else {
      root.opacity = 0
      LockState.forgetScreen(root)
    }
  }

  NumberAnimation {
    id: showAnim

    target: root
    property: "opacity"
    to: 1
    duration: 200
    easing.type: Easing.OutSine
  }

  Component.onCompleted: {
    if (root.shown) {
      root.opacity = 0
      showAnim.restart()
      LockState.noteScreen(root)
    }
  }

  Component.onDestruction: LockState.forgetScreen(root)

  MouseArea {
    anchors.fill: parent

    cursorShape: Qt.PointingHandCursor
    onClicked: field.forceActiveFocus()
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(16 * Theme.scale)

    Rectangle {
      id: fieldBox

      width: Math.round(360 * Theme.scale)
      height: Math.round(56 * Theme.scale)
      radius: Theme.rowRadius
      color: Theme.surface
      border.width: Math.round(2 * Theme.scale)
      border.color: root.fieldBorder
      anchors.horizontalCenter: parent.horizontalCenter

      TextInput {
        id: field

        anchors.fill: parent
        anchors.leftMargin: Math.round(16 * Theme.scale)
        anchors.rightMargin: Math.round(16 * Theme.scale)
        echoMode: TextInput.Password
        passwordCharacter: "\u2022"
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(20 * Theme.scale)
        color: Theme.text
        selectionColor: Theme.primary
        enabled: root.acceptInput
        focus: root.acceptInput
        cursorVisible: activeFocus
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter

        onTextChanged: if (field.text !== LockState.fieldText) {
          LockState.fieldText = field.text
        }

        onAccepted: root.submitField()

        Keys.onReturnPressed: root.submitField()

        Keys.onEnterPressed: root.submitField()

        Keys.onEscapePressed: field.text = ""

        Keys.onPressed: event => {
          if (event.key === Qt.Key_CapsLock) {
            LockState.capsLock = !LockState.capsLock
          }
        }
      }
    }

    Row {
      spacing: Math.round(8 * Theme.scale)
      anchors.horizontalCenter: parent.horizontalCenter

      Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "x"
        color: Theme.red
        font.pixelSize: Theme.iconSize
        visible: LockState.attempts > 0
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: LockState.attempts > 0 ? String(LockState.attempts) : ""
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
        visible: LockState.attempts > 0
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: LockState.error
        color: Theme.red
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
        visible: LockState.error !== ""
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Caps Lock on"
        color: Theme.yellow
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
        visible: LockState.capsLock
      }
    }

    SystemClock {
      id: clock

      precision: SystemClock.Seconds
    }

    Text {
      text: clock.date.toLocaleString(Theme.locale, "HH:mm:ss")
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(64 * Theme.scale)
      font.letterSpacing: Math.round(2 * Theme.scale)
      anchors.horizontalCenter: parent.horizontalCenter
      verticalAlignment: Text.AlignVCenter
    }

    Text {
      text: clock.date.toLocaleString(Theme.locale, "dddd, d MMMM yyyy")
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(18 * Theme.scale)
      anchors.horizontalCenter: parent.horizontalCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
}
