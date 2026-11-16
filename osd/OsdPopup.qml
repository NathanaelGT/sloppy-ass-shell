import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../components"
import "../services"

PanelWindow {
  id: root

  required property var modelData

  readonly property string screenId: modelData ? modelData.name : ""
  readonly property int osdHeight: Math.round(58 * Theme.scale)
  readonly property int cornerRadius: Theme.cardRadius
  readonly property int contentPadX: Math.round(20 * Theme.scale)
  readonly property int iconSize: Math.round(24 * Theme.scale)
  readonly property int labelWidth: Math.round(48 * Theme.scale)
  readonly property int bodyWidth: Math.round(row.implicitWidth) + contentPadX * 2
  readonly property int cardWidth: bodyWidth + cornerRadius * 2
  readonly property int cardX: Math.round((width - cardWidth) / 2)
  readonly property int cardY: Math.round(slide * osdHeight)
  readonly property bool shown: Osd.visible && Osd.pinScreen === screenId
  readonly property int maskWidth: shown || exiting ? cardWidth : 0
  readonly property int maskHeight: shown || exiting ? osdHeight : 0
  property real slide: 1
  property bool exiting: false

  function completeExit() {
    if (!root.exiting) {
      return
    }
    root.exiting = false
    Osd.releasePin(root.screenId)
  }

  function testRect() {
    return {
      x: root.cardX,
      y: 0,
      width: root.cardWidth,
      height: root.osdHeight
    }
  }

  screen: modelData
  color: "transparent"
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  anchors {
    bottom: true
    left: true
    right: true
  }
  implicitHeight: osdHeight
  WlrLayershell.layer: WlrLayer.Overlay

  mask: Region {
    x: root.cardX
    y: root.cardY
    width: root.maskWidth
    height: root.maskHeight
  }

  onShownChanged: {
    if (root.shown) {
      root.exiting = false
      fallAnim.stop()
      riseAnim.restart()
    } else {
      root.exiting = true
      riseAnim.stop()
      fallAnim.restart()
    }
  }

  Component.onCompleted: {
    if (root.shown) {
      root.slide = 0
    }
    TestDriver.registerOsd(root.screenId, root)
  }
  Component.onDestruction: TestDriver.unregisterOsd(root.screenId)

  NumberAnimation {
    id: riseAnim

    target: root
    property: "slide"
    to: 0
    duration: 220
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: fallAnim

    target: root
    property: "slide"
    to: 1
    duration: 220
    easing.type: Easing.OutCubic
    onFinished: root.completeExit()
  }

  Item {
    id: card

    x: root.cardX
    y: root.cardY
    width: root.cardWidth
    height: root.osdHeight

    BarSurface {
      anchors.fill: parent
      surfaceColor: Theme.mantle
      edgeMargin: root.cornerRadius
      cornerRadius: root.cornerRadius
      barWidth: root.bodyWidth
      barHeight: root.osdHeight
      rotation: 180
    }

    Row {
      id: row

      anchors.centerIn: parent
      spacing: Math.round(12 * Theme.scale)

      Icon {
        visible: !Osd.volumeIcon || Osd.value <= 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        name: Osd.icon
        font.pixelSize: root.iconSize
      }

      VolumeIcon {
        visible: Osd.volumeIcon && Osd.value > 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: root.iconSize
        level: Osd.value
        color: Theme.text
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Osd.value >= 0 ? root.labelWidth : implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: Osd.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(16 * Theme.scale)
        font.bold: true
      }

      Rectangle {
        visible: Osd.value >= 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(160 * Theme.scale)
        height: Math.round(8 * Theme.scale)
        radius: height / 2
        color: Theme.surfaceHigh

        Rectangle {
          width: Math.max(0, Math.min(1, Osd.value)) * parent.width
          height: parent.height
          radius: parent.radius
          color: Theme.primary

          Behavior on width {
            NumberAnimation {
              duration: 150
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }
  }
}
