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
  property int horizontalOffset: 0
  property string vertical: "top"
  property bool attached: true
  property int topMargin: Theme.barThickness
  property int cardWidth: Theme.panelWidth
  property int maxCardHeight: (modelData ? modelData.height : 0) - Theme.barThickness - Math.round(40 * Theme.scale)
  property bool externalRequested: false
  property bool exclusiveFocus: false
  property bool ownerFocused: false
  property bool dismissOnBackdrop: true
  property bool autoFocusKeyCatcher: true
  property var cancelItem: null
  property bool animateCardHeight: false
  property bool animateCardWidth: false
  property bool stemEnabled: false
  property bool stemRight: false
  property real stemX: 0
  property real stemProgress: 0
  readonly property real stemGap: (Theme.barThickness - Theme.capsuleThickness) / 2
  readonly property int stemTop: Math.floor(Theme.barThickness - root.stemGap)
  property bool slideUnlocked: true
  property color contentColor: "transparent"
  property int contentInset: 0
  property int contentOuterPad: contentPad
  property bool closePending: false
  property SmoothScroll scrollDriver: scrollerScroll
  default property alias cardData: bodyColumn.data
  property alias headerData: headerColumn.data
  property alias overlayData: overlayArea.data
  property alias gutterData: gutterStrip.data

  signal opened
  signal scrolled
  signal keyPressed(var event)
  signal keyReleased(var event)
  signal cancelRequested
  signal contentClicked(var globalPos)

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
  readonly property bool keepOpen: cardHovered || Panels.barHoverScreen === screenId || popupOpen || (root.scrollDriver ? root.scrollDriver.dragActive : false)

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

    Region {
      x: root.cardWidth
      y: 0
      width: root.gutterActive ? Theme.scrollThumbStrip : 0
      height: root.gutterActive ? root.cardHeight : 0
    }
  }

  Region {
    id: fullMask

    x: 0
    y: 0
    width: root.width
    height: root.height
  }

  WlrLayershell.layer: exclusiveFocus || topDocked ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.keyboardFocus: root.exclusiveFocus && root.ownerFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

  readonly property int shadowPad: Theme.shadowPad
  readonly property int contentPad: Math.round(14 * Theme.scale)
  readonly property bool topDocked: attached && Hypr.fullscreen(screenId)
  readonly property int dockY: topDocked ? 0 : Theme.barThickness
  readonly property int cornerRadius: attached ? Math.min(Theme.cardRadius, edge) : Theme.cardRadius
  readonly property int headerHeight: headerColumn.implicitHeight
  property int cardHeight: Math.min(bodyColumn.implicitHeight + (root.headerHeight > 0 ? root.headerHeight + Theme.gap : 0) + contentPad + contentOuterPad + contentInset, maxCardHeight)

  Behavior on cardHeight {
    enabled: root.animateCardHeight
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  Behavior on cardWidth {
    enabled: root.animateCardWidth
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  NumberAnimation {
    id: stemInAnim

    target: root
    property: "stemProgress"
    to: 1
    duration: 150
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: stemOutAnim

    target: root
    property: "stemProgress"
    to: 0
    duration: 150
    easing.type: Easing.OutCubic
  }
  readonly property int cardX: align === "center" ? Math.round((width - cardWidth) / 2) + horizontalOffset : align === "left" ? edge + horizontalOffset : width - cardWidth - edge + horizontalOffset
  readonly property int restingY: vertical === "center" ? Math.round(((modelData ? modelData.height : 0) - cardHeight) / 2) : topMargin
  readonly property int contentWidth: cardWidth - contentOuterPad * 2
  readonly property int contentInnerWidth: contentWidth - contentInset * 2
  readonly property real contentHeight: bodyColumn.implicitHeight
  readonly property real viewportHeight: scroller.height
  readonly property real viewportY: scroller.y
  readonly property real scrollY: scroller.contentY
  readonly property bool gutterActive: root.scrollDriver ? root.scrollDriver.maxScroll > 0 : false

  function ensureVisible(y, height, margin) {
    scrollerScroll.snap()
    const viewH = scroller.height
    const maxY = Math.max(0, scroller.contentHeight - viewH)
    const pad = margin === undefined ? Math.round(8 * Theme.scale) : margin
    let target = scroller.contentY
    if (y - pad < target) {
      target = y - pad
    } else if (y + height + pad > target + viewH) {
      target = y + height + pad - viewH
    }
    scroller.contentY = Math.max(0, Math.min(maxY, target))
  }

  function scrollToTop() {
    scrollerScroll.snap()
    scroller.contentY = 0
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
      root.ownerFocused = Hypr.focusedScreenName === root.screenId
      open = true
      if (Panels.closingScreen === root.screenId) {
        Panels.closingScreen = ""
      }
      stemOutAnim.stop()
      stemInAnim.restart()
      if (root.stemEnabled) {
        root.slideUnlocked = false
        stemSlideDelay.restart()
      } else {
        root.slideUnlocked = true
      }
    } else {
      open = false
      if (root.attached && root.panelName !== "") {
        Panels.closingScreen = root.screenId
      }
      closeDelay.restart()
      if (root.stemEnabled && !root.slideUnlocked) {
        root.slideUnlocked = true
        stemSlideDelay.stop()
        stemOutAnim.restart()
        root.closePending = false
        Panels.closeCleared(root.panelName, root.screenId)
      }
    }
  }

  onOpenChanged: {
    root.closePending = !root.open
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
    } else if (root.scrollDriver) {
      root.scrollDriver.dragActive = false
    }
  }

  Timer {
    id: closeDelay

    interval: root.stemEnabled ? 420 : 260
    running: false
    onTriggered: if (Panels.closingScreen === root.screenId) {
      Panels.closingScreen = ""
    }
  }

  Timer {
    id: stemSlideDelay

    interval: 150
    running: false
    onTriggered: root.slideUnlocked = true
  }

  MouseArea {
    id: backdrop

    anchors.fill: parent
    onClicked: if (root.dismissOnBackdrop && !root.popupOpen) {
      Panels.close()
    }
    onWheel: event => {
      scrollerScroll.wheel(event)
      event.accepted = true
    }
  }

  Item {
    id: clipFrame

    x: 0
    y: root.attached ? root.dockY : 0
    width: root.width
    height: root.attached ? root.height - root.dockY : root.height
    clip: root.attached

    Item {
      id: visual

      x: root.cardX - root.shadowPad
      y: root.open && root.slideUnlocked ? (root.attached ? -root.shadowPad : root.restingY - root.shadowPad) : -height
      width: root.cardWidth + root.shadowPad * 2
      height: root.cardHeight + root.shadowPad * 2
      layer.enabled: true
      layer.samples: 4

      onYChanged: {
        if (!root.closePending || !root.attached) {
          return
        }
        if (visual.y > -visual.height + 0.5) {
          return
        }
        root.closePending = false
        Panels.closeCleared(root.panelName, root.screenId)
        if (root.stemEnabled) {
          stemOutAnim.restart()
        }
      }

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

        Rectangle {
          visible: root.contentColor.a > 0
          x: root.contentOuterPad
          y: 0
          width: root.contentWidth
          height: Math.max(0, root.cardHeight - root.contentOuterPad)
          radius: Theme.rowRadius
          topLeftRadius: root.stemRight ? Theme.rowRadius : 0
          topRightRadius: root.stemRight ? 0 : Theme.rowRadius
          color: root.contentColor
          antialiasing: true
        }

        MouseArea {
          anchors.fill: parent
          onWheel: event => {
            scrollerScroll.wheel(event)
            event.accepted = true
          }
        }

        MouseArea {
          anchors.fill: parent
          onPressed: mouse => {
            root.contentClicked(mapToItem(null, mouse.x, mouse.y))
            mouse.accepted = false
          }
        }

        Item {
          id: headerArea

          anchors.top: contentClip.top
          anchors.left: contentClip.left
          anchors.right: contentClip.right
          anchors.topMargin: root.contentPad
          anchors.leftMargin: root.contentOuterPad + root.contentInset
          anchors.rightMargin: root.contentOuterPad + root.contentInset
          height: root.headerHeight
          visible: root.headerHeight > 0
          clip: true

          Column {
            id: headerColumn

            width: parent.width
            spacing: Theme.gap
          }
        }

        Flickable {
          id: scroller

          anchors.left: contentClip.left
          anchors.right: contentClip.right
          anchors.bottom: contentClip.bottom
          anchors.leftMargin: root.contentOuterPad + root.contentInset
          anchors.rightMargin: root.contentOuterPad + root.contentInset
          anchors.bottomMargin: root.contentOuterPad + root.contentInset
          anchors.top: headerArea.visible ? headerArea.bottom : contentClip.top
          anchors.topMargin: headerArea.visible ? Theme.gap : root.contentPad
          contentWidth: width
          contentHeight: bodyColumn.implicitHeight
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds
          interactive: false
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

        TopCutCorners {
          visible: root.contentColor.a > 0 && root.scrollY > 0
          x: scroller.x
          y: scroller.y
          width: scroller.width
          color: root.contentColor
          z: 100
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

        SmoothScroll {
          id: scrollerScroll

          target: scroller
          anchors.fill: scroller
        }

        Item {
          id: overlayArea

          anchors.fill: parent
          z: 10
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

      Item {
        id: gutterStrip

        x: root.shadowPad + root.cardWidth
        y: root.shadowPad
        width: Theme.scrollThumbStrip
        height: root.cardHeight

        MouseArea {
          anchors.fill: parent
          enabled: root.gutterActive
          onWheel: event => {
            if (root.scrollDriver) {
              root.scrollDriver.wheel(event)
            }
            event.accepted = true
          }
        }

        ScrollGutter {
          track: scrollerScroll

          y: scroller.y
          height: scroller.height
        }
      }
    }
  }

  Item {
    id: stem

    visible: root.stemEnabled && root.stemProgress > 0 && !root.topDocked
    x: root.stemX
    y: root.stemTop
    width: Theme.capsuleThickness
    height: (Theme.barThickness - root.stemTop) * root.stemProgress

    property color fill: root.requested ? Theme.capsuleHover : Theme.capsuleFill

    Behavior on fill {
      ColorAnimation {
        duration: 120
      }
    }

    Rectangle {
      anchors.fill: parent
      color: stem.fill
      antialiasing: true
    }

    InnerFillet {
      x: root.stemRight ? -radius + 1 : stem.width - 1
      y: stem.height - radius
      mirror: !root.stemRight
      radius: Theme.barThickness / 2 * root.stemProgress
      color: stem.fill
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
    Keys.onReleased: event => root.keyReleased(event)
  }
}
