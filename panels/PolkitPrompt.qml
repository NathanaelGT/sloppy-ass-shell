import QtQuick
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  align: "center"
  attached: true
  topMargin: Theme.barThickness + Math.round(6 * Theme.scale)
  cardWidth: Math.round(420 * Theme.scale)
  exclusiveFocus: true
  dismissOnBackdrop: false
  autoFocusKeyCatcher: false
  externalRequested: Polkit.active && Polkit.pinScreen === screenId
  property string errorText: ""
  property bool shaking: false

  function failAttempt() {
    const flow = Polkit.flow
    root.errorText = flow && flow.supplementaryMessage !== "" ? flow.supplementaryMessage : "Sorry, that didn't work. Please try again."
    response.text = ""
    fieldBox.failTint = true
    tintTimer.restart()
    response.forceActiveFocus()
    root.shaking = true
    shakeAnim.restart()
  }

  function testState() {
    return {
      open: root.open,
      screenId: root.screenId,
      fake: Polkit.fakeActive,
      error: root.errorText,
      inputLength: response.text.length,
      shaking: root.shaking,
      failTint: fieldBox.failTint
    }
  }

  onOpened: {
    response.text = ""
    root.errorText = ""
    fieldBox.failTint = false
    tintTimer.stop()
    shakeAnim.stop()
    shakeTranslate.x = 0
    root.shaking = false
    response.forceActiveFocus()
  }

  Connections {
    target: root

    function onOpenChanged() {
      if (root.open) {
        TestDriver.register("polkit", root.screenId, root)
      } else {
        TestDriver.unregister("polkit", root.screenId)
      }
    }
  }

  Connections {
    target: Polkit.flow

    function onAuthenticationFailed() {
      root.failAttempt()
    }
  }

  Column {
    id: content

    width: Math.round(380 * Theme.scale)
    x: Math.round((parent.width - width) / 2)
    spacing: Math.round(12 * Theme.scale)

    Text {
      width: parent.width
      text: Polkit.flow ? Polkit.flow.message : ""
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLarge
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      visible: text.length > 0
      text: Polkit.flow ? Polkit.flow.inputPrompt : ""
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      wrapMode: Text.WordWrap
    }

    Rectangle {
      id: fieldBox

      property bool failTint: false

      width: parent.width
      height: Math.round(40 * Theme.scale)
      radius: Math.round(10 * Theme.scale)
      color: Theme.surface
      border.width: Math.round(2 * Theme.scale)
      border.color: failTint ? Theme.red : fieldBox.color
      transform: Translate {
        id: shakeTranslate
      }

      TextInput {
        id: response
        anchors.fill: parent
        anchors.margins: Math.round(10 * Theme.scale)
        color: Theme.text
        echoMode: Polkit.flow && Polkit.flow.responseVisible ? TextInput.Normal : TextInput.Password
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true
        onAccepted: {
          if (Polkit.flow) {
            Polkit.flow.submit(text)
          }
        }
        onTextEdited: root.errorText = ""
      }
    }

    Text {
      width: parent.width
      visible: root.errorText !== ""
      text: root.errorText
      color: Theme.red
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      visible: text.length > 0 && !(root.errorText !== "" && Polkit.flow && Polkit.flow.supplementaryIsError)
      text: Polkit.flow ? Polkit.flow.supplementaryMessage : ""
      color: Polkit.flow && Polkit.flow.supplementaryIsError ? Theme.red : Theme.yellow
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      wrapMode: Text.WordWrap
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Math.round(10 * Theme.scale)

      Tile {
        width: Math.round(150 * Theme.scale)
        icon: "x"
        label: "Cancel"
        onClicked: {
          if (Polkit.flow) {
            Polkit.flow.cancelAuthenticationRequest()
          }
        }
      }

      Tile {
        width: Math.round(150 * Theme.scale)
        icon: "check"
        label: "Authenticate"
        active: true
        onClicked: {
          if (Polkit.flow) {
            Polkit.flow.submit(response.text)
          }
        }
      }
    }
  }

  Timer {
    id: tintTimer

    interval: 600
    running: false
    onTriggered: fieldBox.failTint = false
  }

  SequentialAnimation {
    id: shakeAnim

    readonly property int swing: Math.round(6 * Theme.scale)

    NumberAnimation {
      target: shakeTranslate
      property: "x"
      to: -shakeAnim.swing
      duration: 75
    }

    NumberAnimation {
      target: shakeTranslate
      property: "x"
      to: shakeAnim.swing
      duration: 75
    }

    NumberAnimation {
      target: shakeTranslate
      property: "x"
      to: -shakeAnim.swing
      duration: 75
    }

    NumberAnimation {
      target: shakeTranslate
      property: "x"
      to: 0
      duration: 75
    }

    onStopped: root.shaking = false
  }
}
