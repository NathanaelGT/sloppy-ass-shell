import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../components"
import "../services"

PanelWindow {
  id: root

  required property var modelData

  property string panelName: ""
  property string align: "right"
  property string vertical: "top"
  property bool attached: true
  property int topMargin: Theme.barThickness
  property int cardWidth: Theme.panelWidth
  property int maxCardHeight: (modelData ? modelData.height : 0) - Theme.barThickness - Math.round(40 * Theme.scale)
  property bool externalRequested: false
  property bool exclusiveFocus: false
  property bool dismissOnBackdrop: true
  property bool autoFocusKeyCatcher: true
  property var cancelItem: null
  property bool animateCardHeight: false
  default property alias cardData: bodyColumn.data

  signal opened
  signal scrolled
  signal keyPressed(var event)
  signal cancelRequested

  screen: modelData
  readonly property string screenId: modelData ? modelData.name : ""
  readonly property int edge: screenId === "eDP-1" ? Theme.cardRadius : Theme.barMargin + (attached ? Theme.menuRightInset : 0)
  readonly property bool requested: panelName === "" ? externalRequested : (Panels.panel === panelName && Panels.screenName === screenId)

  property bool open: false
  property string windowAtOpen: ""
  property bool exitCloseArmed: false
  property bool cardHovered: false
  property bool popupOpen: false
  readonly property bool exitCloseActive: open && dismissOnBackdrop && !exclusiveFocus
  readonly property bool keepOpen: cardHovered || Panels.barHoverScreen === screenId || popupOpen

  color: "transparent"
  visible: requested || closeDelay.running

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  aboveWindows: true
  focusable: true

  mask: root.popupOpen ? fullMask : cardMask

  Region {
    id: cardMask

    x: root.cardX
    y: clipFrame.y + visual.y + root.shadowPad
    width: root.cardWidth
    height: root.cardHeight
    radius: root.cornerRadius
  }

  Region {
    id: fullMask

    x: 0
    y: 0
    width: root.width
    height: root.height
  }

  WlrLayershell.layer: exclusiveFocus ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.keyboardFocus: exclusiveFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

  readonly property int shadowPad: Theme.shadowPad
  readonly property int contentPad: Math.round(14 * Theme.scale)
  readonly property int cornerRadius: attached ? Math.min(Theme.cardRadius, edge) : Theme.cardRadius
  property int cardHeight: Math.min(bodyColumn.implicitHeight + contentPad * 2, maxCardHeight)

  Behavior on cardHeight {
    enabled: root.animateCardHeight
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }
  readonly property int cardX: align === "center" ? Math.round((width - cardWidth) / 2) : align === "left" ? edge : width - cardWidth - edge
  readonly property int restingY: vertical === "center" ? Math.round(((modelData ? modelData.height : 0) - cardHeight) / 2) : topMargin
  readonly property int contentWidth: cardWidth - contentPad * 2
  readonly property real contentHeight: bodyColumn.implicitHeight
  readonly property real viewportHeight: scroller.height

  function scrollBy(delta) {
    const limit = Math.max(0, scroller.contentHeight - scroller.height)
    scroller.contentY = Math.max(0, Math.min(limit, scroller.contentY - delta / 2))
  }

  function hitCancelTarget(lx, ly) {
    const target = root.cancelItem
    if (!target) {
      return false
    }
    const point = target.mapToItem(contentClip, 0, 0)
    return point && lx >= point.x && lx <= point.x + target.width && ly >= point.y && ly <= point.y + target.height
  }

  function targetPressAt(lx, ly) {
    const target = root.cancelItem
    if (!target) {
      return
    }
    const point = target.mapToItem(contentClip, 0, 0)
    if (point) {
      target.testPressAt(lx - point.x, ly - point.y)
    }
  }

  function testDispatch(x, y) {
    if (!root.cancelItem) {
      return "idle"
    }
    const origin = contentClip.mapToItem(null, 0, 0)
    if (root.hitCancelTarget(x - origin.x, y - origin.y)) {
      root.targetPressAt(x - origin.x, y - origin.y)
      return "passthrough"
    }
    root.cancelRequested()
    return "cancelled"
  }

  function testRect() {
    const point = visual.mapToItem(null, 0, 0)
    if (!point) {
      return null
    }
    return {
      x: point.x,
      y: point.y,
      width: visual.width,
      height: visual.height
    }
  }

  onRequestedChanged: {
    if (requested) {
      closeDelay.stop()
      open = true
      if (Panels.closingScreen === root.screenId) {
        Panels.closingScreen = ""
      }
    } else {
      open = false
      if (root.attached && root.panelName !== "") {
        Panels.closingScreen = root.screenId
      }
      closeDelay.restart()
    }
  }

  onOpenChanged: {
    if (root.panelName !== "") {
      if (root.open) {
        TestDriver.register(root.panelName, root.screenId, root)
      } else {
        TestDriver.unregister(root.panelName, root.screenId)
      }
    }
    if (root.open) {
      root.windowAtOpen = Hypr.activeWindowAddress
    }
    if (!root.open) {
      root.exitCloseArmed = false
      root.cardHovered = false
      exitTimer.stop()
    }
  }

  onKeepOpenChanged: {
    if (root.keepOpen) {
      root.exitCloseArmed = true
      exitTimer.stop()
    } else if (root.exitCloseArmed && root.exitCloseActive) {
      exitTimer.restart()
    }
  }

  Connections {
    target: Hypr

    function onActiveWindowAddressChanged() {
      if (!root.open || !root.dismissOnBackdrop) {
        return
      }
      if (Hypr.activeWindowAddress === root.windowAtOpen) {
        return
      }
      Panels.close()
    }
  }

  Timer {
    id: exitTimer

    interval: 180
    running: false
    onTriggered: if (root.exitCloseActive && !root.keepOpen) {
      Panels.close()
    }
  }

  onVisibleChanged: {
    if (visible) {
      if (autoFocusKeyCatcher) {
        keyCatcher.forceActiveFocus()
      }
      root.opened()
    }
  }

  Timer {
    id: closeDelay

    interval: 260
    running: false
    onTriggered: if (Panels.closingScreen === root.screenId) {
      Panels.closingScreen = ""
    }
  }

  MouseArea {
    id: backdrop

    anchors.fill: parent
    onClicked: if (root.dismissOnBackdrop && !root.popupOpen) {
      Panels.close()
    }
    onWheel: event => {
      root.scrollBy(event.angleDelta.y)
      event.accepted = true
    }
  }

  Item {
    id: clipFrame

    x: 0
    y: root.attached ? Theme.barThickness : 0
    width: root.width
    height: root.attached ? root.height - Theme.barThickness : root.height
    clip: root.attached

    Item {
      id: visual

      x: root.cardX - root.shadowPad
      y: root.open ? (root.attached ? -root.shadowPad : root.restingY - root.shadowPad) : -height
      width: root.cardWidth + root.shadowPad * 2
      height: root.cardHeight + root.shadowPad * 2
      layer.enabled: true
      layer.samples: 4

      Behavior on y {
        NumberAnimation {
          duration: 220
          easing.type: Easing.OutCubic
        }
      }

      HoverHandler {
        onHoveredChanged: root.cardHovered = hovered
      }

      BarSurface {
        id: concaveSurface

        x: root.shadowPad - root.cornerRadius
        y: root.shadowPad
        width: root.cardWidth + root.cornerRadius * 2
        height: root.cardHeight
        surfaceColor: Theme.base
        edgeMargin: root.cornerRadius
        cornerRadius: root.cornerRadius
        barWidth: root.cardWidth
        barHeight: root.cardHeight
        visible: false
      }

      Rectangle {
        id: roundedSurface

        x: root.shadowPad
        y: root.shadowPad
        width: root.cardWidth
        height: root.cardHeight
        radius: root.cornerRadius
        color: Theme.base
        antialiasing: true
        visible: false
      }

      PanelShadow {
        shadowSource: root.attached ? concaveSurface : roundedSurface
      }

      MouseArea {
        anchors.fill: parent
        onClicked: if (root.dismissOnBackdrop && !root.popupOpen) {
          Panels.close()
        }
      }

      Item {
        id: contentClip

        x: root.shadowPad
        y: root.shadowPad
        width: root.cardWidth
        height: root.cardHeight
        clip: true

        MouseArea {
          anchors.fill: parent
          onWheel: event => {
            root.scrollBy(event.angleDelta.y)
            event.accepted = true
          }
        }

        Flickable {
          id: scroller

          anchors.fill: parent
          anchors.margins: root.contentPad
          contentWidth: width
          contentHeight: bodyColumn.implicitHeight
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          clip: true
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: scrollerMask
          }
          onContentYChanged: root.scrolled()

          Column {
            id: bodyColumn

            width: scroller.width
            spacing: Theme.gap
          }
        }

        Item {
          id: scrollerMask

          x: scroller.x
          y: scroller.y
          width: scroller.width
          height: scroller.height
          visible: false
          layer.enabled: true

          Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius
            color: "white"
            antialiasing: true
          }
        }

        MouseArea {
          anchors.fill: parent
          visible: root.cancelItem !== null && root.cancelItem !== undefined
          hoverEnabled: true
          propagateComposedEvents: true
          cursorShape: containsMouse && root.hitCancelTarget(mouseX, mouseY) ? Qt.IBeamCursor : Qt.ArrowCursor
          onPressed: mouse => {
            if (root.hitCancelTarget(mouse.x, mouse.y)) {
              mouse.accepted = false
            }
          }
          onClicked: mouse => {
            if (root.hitCancelTarget(mouse.x, mouse.y)) {
              mouse.accepted = false
              return
            }
            root.cancelRequested()
          }
        }
      }
    }
  }

  Item {
    id: keyCatcher

    anchors.fill: parent
    focus: root.autoFocusKeyCatcher
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        Panels.close()
        event.accepted = true
      } else {
        root.keyPressed(event)
      }
    }
  }
}
