import QtQuick
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  align: "center"
  vertical: "center"
  attached: false
  cardWidth: Math.round(420 * Theme.scale)
  exclusiveFocus: true
  dismissOnBackdrop: false
  autoFocusKeyCatcher: false
  externalRequested: Polkit.active && Hypr.focusedScreenName === screenId

  onOpened: {
    response.text = ""
    response.forceActiveFocus()
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
      width: parent.width
      height: Math.round(40 * Theme.scale)
      radius: Math.round(10 * Theme.scale)
      color: Theme.surface

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
      }
    }

    Text {
      width: parent.width
      visible: text.length > 0
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
}
