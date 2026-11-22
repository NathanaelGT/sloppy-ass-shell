import QtQuick
import "../theme"
import "../components"

Rectangle {
  id: root

  property var panel: null

  readonly property bool open: panel ? panel.scanOpen : false
  readonly property int pad: Math.round(12 * Theme.scale)

  width: parent ? parent.width : 0
  height: visible ? content.implicitHeight + root.pad * 2 : 0
  color: Theme.surface
  radius: Theme.rowRadius

  Item {
    id: focusHold

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape && root.panel) {
        root.panel.closeScanCard()
        event.accepted = true
      }
    }
  }

  onVisibleChanged: if (visible) {
    focusHold.forceActiveFocus()
  }

  Column {
    id: content

    x: root.pad
    y: root.pad
    width: parent.width - root.pad * 2
    spacing: Math.round(10 * Theme.scale)

    Item {
      id: previewHost

      // Double buffer with backpressure: the newest frame decodes into the
      // image currently at the back; when it reports Ready it is promoted
      // over the front one. Frames arriving mid-decode are dropped, so the
      // front image always holds a fully decoded frame and never blanks.
      property string bufA: ""
      property string bufB: ""
      property bool frontIsA: false
      property bool backDecoding: false

      readonly property bool hasFrame: bufA !== "" || bufB !== ""

      visible: root.panel ? root.panel.scanFrame !== "" : false
      width: parent.width
      height: visible ? Math.round(width * 0.75) : 0

      Connections {
        target: root.panel

        function onScanFrameChanged() {
          if (!root.panel || root.panel.scanFrame === "" || previewHost.backDecoding) {
            return
          }
          previewHost.backDecoding = true
          if (previewHost.frontIsA) {
            previewHost.bufB = root.panel.scanFrame
          } else {
            previewHost.bufA = root.panel.scanFrame
          }
        }
      }

      Image {
        id: previewA

        anchors.fill: parent
        visible: previewHost.bufA !== ""
        z: previewHost.frontIsA ? 1 : 0
        fillMode: Image.PreserveAspectFit
        cache: false
        asynchronous: false
        source: previewHost.bufA !== "" ? "data:image/jpeg;base64," + previewHost.bufA : ""

        transform: Scale {
          xScale: -1
          origin.x: previewA.width / 2
        }
        onStatusChanged: if (status === Image.Ready && !previewHost.frontIsA && previewHost.backDecoding) {
          previewHost.frontIsA = true
          previewHost.backDecoding = false
        }
      }

      Image {
        id: previewB

        anchors.fill: parent
        visible: previewHost.bufB !== ""
        z: previewHost.frontIsA ? 0 : 1
        fillMode: Image.PreserveAspectFit
        cache: false
        asynchronous: false
        source: previewHost.bufB !== "" ? "data:image/jpeg;base64," + previewHost.bufB : ""

        transform: Scale {
          xScale: -1
          origin.x: previewB.width / 2
        }
        onStatusChanged: if (status === Image.Ready && previewHost.frontIsA && previewHost.backDecoding) {
          previewHost.frontIsA = false
          previewHost.backDecoding = false
        }
      }
    }

    Row {
      width: parent.width
      spacing: Math.round(6 * Theme.scale)

      Text {
        width: parent.width - pasteBtn.width - closeBtn.width - parent.spacing * 3
        anchors.verticalCenter: pasteBtn.verticalCenter
        text: "Hold a Wi-Fi QR code in front of the camera"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        elide: Text.ElideRight
      }

      IconButton {
        id: pasteBtn

        size: Math.round(26 * Theme.scale)
        glyphSize: Math.round(15 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        name: "photo"
        iconColor: pasteBtn.hovered ? Theme.text : Theme.overlay
        hoverColor: Theme.surfaceHigher
        onClicked: if (root.panel) {
          root.panel.pasteScan()
        }
      }

      IconButton {
        id: closeBtn

        size: Math.round(26 * Theme.scale)
        glyphSize: Math.round(15 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        name: "x"
        iconColor: closeBtn.hovered ? Theme.text : Theme.overlay
        hoverColor: Theme.surfaceHigher
        onClicked: if (root.panel) {
          root.panel.closeScanCard()
        }
      }
    }

    Text {
      width: parent.width
      text: root.panel ? root.panel.scanStatus : ""
      color: Theme.overlay
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      elide: Text.ElideRight
    }
  }
}
