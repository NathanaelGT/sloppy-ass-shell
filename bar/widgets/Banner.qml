import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import "../../theme"
import "../../components"
import "../../services"

Item {
  id: root

  property var screen
  property real clockWidth: 0
  property real bellWidth: 0
  property real centerGap: 0
  property bool lobeHovered: false
  property var displayed: null
  property real blobWidth: root.restWidth
  property real expand: 0
  property real swapOpacity: 1
  readonly property bool separated: Notifs.bannerPhase === "hidden" || Notifs.bannerPhase === "retreating"
  property real separation: 1
  property real lobeOpacity: 0
  readonly property real innerRadius: Theme.capsuleRadius * root.separation

  readonly property string screenId: screen.name
  readonly property bool open: screen.name === "eDP-1" && Notifs.bannerVisible
  readonly property bool detailOpen: Notifs.bannerPhase === "expanded"
  readonly property bool critical: Notifs.bannerCritical
  readonly property real restWidth: clockWidth + centerGap + bellWidth
  readonly property real pad: Math.round(12 * Theme.scale)
  readonly property real headerDrop: root.detailOpen ? Math.max(0, Math.round(root.pad - (Theme.capsuleThickness - Theme.bannerIconSize) / 2)) : 0
  readonly property real pillY: (Theme.barThickness - Theme.capsuleThickness) / 2
  readonly property real compactLeft: pad + bellWidth + centerGap
  readonly property real compactRight: blobWidth - pad
  readonly property real compactWidth: Math.max(0, compactRight - compactLeft)
  readonly property real expandTarget: Math.min(Theme.bannerMaxExpand, Math.round(pad * 2 + contentCol.implicitHeight))
  readonly property bool hovered: hoverHandler.hovered || root.lobeHovered
  readonly property var rows: Notifs.bannerRows
  readonly property int count: Notifs.bannerCount
  readonly property int more: Notifs.bannerMore
  readonly property bool hasRows: rows.length > 0
  readonly property bool hasBody: root.displayed !== null && String(root.displayed.body).length > 0
  readonly property bool hasImage: root.displayed !== null && String(root.displayed.image).length > 0
  readonly property string appIconSource: root.displayed !== null ? Quickshell.iconPath(AppIcons.forNotification(root.displayed.appIcon, root.displayed.desktopEntry, root.displayed.appName), "dialog-information") : ""
  property string lastIcon: ""
  property real iconDock: 0
  property real iconOpacity: 0
  readonly property real iconRestLeft: (root.bellWidth - Theme.bannerIconSize) / 2
  readonly property int actionCount: Math.min(3, root.displayed !== null ? root.displayed.actions.length : 0)

  onAppIconSourceChanged: if (root.appIconSource !== "") {
    root.lastIcon = root.appIconSource
  }

  width: blobWidth
  height: Theme.barThickness + Theme.bannerMaxExpand
  visible: screen.name === "eDP-1"

  function snapshot(record) {
    return {
      n: record.n,
      appName: record.snap.appName,
      appIcon: record.snap.appIcon,
      desktopEntry: record.snap.desktopEntry,
      summary: record.snap.summary,
      body: record.snap.body,
      urgency: record.snap.urgency,
      actions: record.snap.actions,
      image: record.snap.image || String(record.n.image || "")
    }
  }

  function setDisplayed(record) {
    replaceAnim.stop()
    root.displayed = root.snapshot(record)
    root.swapOpacity = 1
  }

  function sameDisplay(a, b) {
    if (a === null || b === null) {
      return false
    }
    return a.n === b.n && a.appName === b.appName && a.appIcon === b.appIcon && a.desktopEntry === b.desktopEntry && a.summary === b.summary && a.body === b.body && a.urgency === b.urgency && String(a.image) === String(b.image) && a.actions.join("\u001f") === b.actions.join("\u001f")
  }

  function syncSelected() {
    if (!root.open || Notifs.bannerSelected === null) {
      return
    }
    if (root.displayed === null) {
      root.setDisplayed(Notifs.bannerSelected)
      return
    }
    if (root.sameDisplay(root.displayed, root.snapshot(Notifs.bannerSelected))) {
      return
    }
    replaceAnim.restart()
  }

  function syncIcon() {
    if (Notifs.bannerPhase === "compact" || Notifs.bannerPhase === "expanded") {
      iconHideAnim.stop()
      dockOutAnim.stop()
      iconRetreatFadeAnim.stop()
      iconShowAnim.restart()
      dockInAnim.restart()
      return
    }
    dockInAnim.stop()
    dockOutAnim.restart()
    if (Notifs.bannerPhase === "retreating") {
      iconHideAnim.stop()
      iconRetreatFadeAnim.restart()
      return
    }
    if (Notifs.bannerPhase === "hidden") {
      iconHideAnim.restart()
    }
  }

  function syncSeparation() {
    if (Notifs.bannerPhase === "hidden") {
      closeAnim.stop()
      lobeShowAnim.stop()
      if (!splitAnim.running && root.separation < 0.999) {
        splitAnim.restart()
      }
      if (!lobeHideAnim.running && root.lobeOpacity > 0.001) {
        lobeHideAnim.restart()
      }
      return
    }
    if (root.separated) {
      closeAnim.stop()
      lobeHideAnim.stop()
      if (!splitAnim.running && root.separation < 0.999) {
        splitAnim.restart()
      }
      if (!lobeShowAnim.running && root.lobeOpacity < 0.999) {
        lobeShowAnim.restart()
      }
      return
    }
    splitAnim.stop()
    closeAnim.restart()
    lobeHideAnim.stop()
    if (!lobeShowAnim.running && root.lobeOpacity < 0.999) {
      lobeShowAnim.restart()
    }
  }

  function openNotifications() {
    if (Notifs.bannerVisible) {
      Notifs.acknowledgeBanner()
    }
    Panels.toggle("notifications", root.screen.name)
  }

  function invokeAction(index) {
    if (root.displayed === null || !root.displayed.n) {
      return false
    }
    const n = root.displayed.n
    if (index < 0 || index >= n.actions.length) {
      return false
    }
    n.actions[index].invoke()
    n.dismiss()
    return true
  }

  function testInvoke(zone) {
    if (!root.open) {
      return false
    }
    if (zone === "bell") {
      root.openNotifications()
      return true
    }
    if (zone === "compact") {
      return Notifs.expandBannerNow()
    }
    if (zone === "detail" || zone === "more") {
      root.openNotifications()
      return true
    }
    if (zone === "dismissSelected") {
      return Notifs.dismissBannerSelected()
    }
    if (zone === "dismissAll" || zone === "bellDismissAll") {
      Notifs.dismissAll()
      return true
    }
    if (zone === "bellDnd") {
      Notifs.dnd = !Notifs.dnd
      return true
    }
    if (zone === "altTime") {
      ClockState.showAltTime = !ClockState.showAltTime
      return true
    }
    if (zone.indexOf("row") === 0) {
      return Notifs.selectBannerRow(Number(zone.substring(3)))
    }
    if (zone.indexOf("dismissRow") === 0) {
      return Notifs.dismissBannerRow(Number(zone.substring(10)))
    }
    if (zone.indexOf("action") === 0) {
      return root.invokeAction(Number(zone.substring(6)))
    }
    return false
  }

  function testRect() {
    if (!root.open) {
      return null
    }
    return {
      x: root.x,
      y: root.pillY,
      width: root.blobWidth,
      height: Theme.capsuleThickness + root.expand
    }
  }

  function testMetrics() {
    return {
      width: Math.round(root.blobWidth),
      expand: Math.round(root.expand),
      target: Math.round(root.expandTarget),
      content: Math.round(contentCol.implicitHeight),
      compactWidth: Math.round(root.compactWidth),
      detailOpen: root.detailOpen,
      displayed: root.displayed !== null,
      bodyVisible: bodyLabel.visible,
      bodyHeight: Math.round(bodyLabel.height),
      rightLobeOpacity: Math.round(rightLobe.opacity * 100) / 100,
      separation: Math.round(root.separation * 100) / 100
    }
  }

  onExpandTargetChanged: if (root.detailOpen) {
    root.expand = root.expandTarget
  }

  onDetailOpenChanged: root.expand = root.detailOpen ? root.expandTarget : 0

  onHoveredChanged: if (root.open) {
    Notifs.setBannerHover(root.hovered)
  }

  onOpenChanged: {
    if (root.open) {
      if (root.hovered) {
        Notifs.setBannerHover(true)
      }
    } else {
      Notifs.setBannerHover(false)
    }
  }

  Behavior on blobWidth {
    NumberAnimation {
      duration: 380
      easing.type: Easing.OutBack
      easing.overshoot: 1.05
    }
  }

  Behavior on expand {
    NumberAnimation {
      duration: 320
      easing.type: Easing.OutCubic
    }
  }

  Behavior on swapOpacity {
    NumberAnimation {
      duration: 120
      easing.type: Easing.OutCubic
    }
  }

  Component.onCompleted: TestDriver.register("banner", screen.name, root)

  Connections {
    target: Notifs

    function onArrivalsChanged() {
      iconShakeAnim.restart()
    }

    function onBannerSelectedChanged() {
      root.syncSelected()
    }

    function onBannerRevisionChanged() {
      root.syncSelected()
    }

    function onBannerPhaseChanged() {
      root.syncSeparation()
      root.syncIcon()
      if (!Notifs.bannerVisible) {
        replaceAnim.stop()
        root.displayed = null
        root.swapOpacity = 1
        root.expand = 0
        return
      }
      if (root.displayed === null && Notifs.bannerSelected !== null) {
        root.setDisplayed(Notifs.bannerSelected)
      }
    }
  }

  SequentialAnimation {
    id: replaceAnim

    NumberAnimation {
      target: root
      property: "swapOpacity"
      to: 0
      duration: 90
      easing.type: Easing.OutCubic
    }

    ScriptAction {
      script: if (Notifs.bannerSelected !== null) {
        root.displayed = root.snapshot(Notifs.bannerSelected)
      }
    }

    NumberAnimation {
      target: root
      property: "swapOpacity"
      to: 1
      duration: 140
      easing.type: Easing.OutCubic
    }
  }

  NumberAnimation {
    id: splitAnim

    target: root
    property: "separation"
    to: 1
    duration: 240
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: closeAnim

    target: root
    property: "separation"
    to: 0
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: lobeShowAnim

    target: root
    property: "lobeOpacity"
    to: 1
    duration: 120
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: iconShowAnim

    target: root
    property: "iconOpacity"
    to: 1
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: iconHideAnim

    target: root
    property: "iconOpacity"
    to: 0
    duration: 280
    easing.type: Easing.InOutSine
  }

  NumberAnimation {
    id: iconRetreatFadeAnim

    target: root
    property: "iconOpacity"
    to: 0
    duration: 120
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: dockInAnim

    target: root
    property: "iconDock"
    to: 1
    duration: 140
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: dockOutAnim

    target: root
    property: "iconDock"
    to: 0
    duration: 320
    easing.type: Easing.OutCubic
  }

  SequentialAnimation {
    id: iconShakeAnim

    NumberAnimation {
      target: dockIcon
      property: "rotation"
      to: -13
      duration: 60
      easing.type: Easing.OutCubic
    }

    NumberAnimation {
      target: dockIcon
      property: "rotation"
      to: 11
      duration: 90
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: dockIcon
      property: "rotation"
      to: -8
      duration: 90
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: dockIcon
      property: "rotation"
      to: 5
      duration: 85
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: dockIcon
      property: "rotation"
      to: -2
      duration: 75
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      target: dockIcon
      property: "rotation"
      to: 0
      duration: 60
      easing.type: Easing.OutCubic
    }
  }

  SequentialAnimation {
    id: lobeHideAnim

    PauseAnimation {
      duration: 300
    }

    NumberAnimation {
      target: root
      property: "lobeOpacity"
      to: 0
      duration: 100
      easing.type: Easing.OutCubic
    }
  }

  HoverHandler {
    id: hoverHandler

    enabled: root.open
  }

  Rectangle {
    id: rightLobe

    x: root.bellWidth + root.centerGap
    y: root.pillY
    width: Math.max(0, root.blobWidth - root.bellWidth - root.centerGap)
    height: Theme.capsuleThickness + root.expand
    radius: Theme.capsuleRadius
    topLeftRadius: root.innerRadius
    bottomLeftRadius: root.innerRadius
    color: root.hovered ? Theme.capsuleHover : Theme.capsuleFill
    opacity: root.lobeOpacity
    antialiasing: true

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }
  }

  ClockFace {
    id: retreatClock

    x: root.bellWidth + root.centerGap
    y: root.pillY
    width: root.clockWidth
    height: Theme.capsuleThickness
    visible: Notifs.bannerPhase === "retreating"
    opacity: root.separation
  }

  Image {
    id: dockIcon

    x: root.iconRestLeft + (root.pad - root.iconRestLeft) * root.iconDock
    y: root.pillY + (Theme.capsuleThickness - Theme.bannerIconSize) / 2 + root.headerDrop
    width: Theme.bannerIconSize
    height: width
    opacity: root.iconOpacity
    visible: opacity > 0
    sourceSize: Qt.size(width, height)
    source: root.appIconSource !== "" ? root.appIconSource : root.lastIcon

    Behavior on y {
      NumberAnimation {
        duration: 320
        easing.type: Easing.OutCubic
      }
    }
  }

  Rectangle {
    id: criticalBorder

    x: 0
    y: root.pillY
    width: root.blobWidth
    height: Theme.capsuleThickness + root.expand
    radius: Theme.capsuleRadius
    color: "transparent"
    border.width: root.critical ? 1 : 0
    border.color: Theme.red
    opacity: root.open && root.critical ? 1 - root.separation : 0
    antialiasing: true
  }

  MouseArea {
    id: detailMouse

    x: 0
    y: root.pillY + Theme.capsuleThickness
    width: root.blobWidth
    height: Math.max(0, root.expand)
    enabled: root.open && root.detailOpen
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: e => e.button === Qt.LeftButton ? root.openNotifications() : e.button === Qt.RightButton ? Notifs.dismissBannerSelected() : Notifs.dismissAll()
  }

  Item {
    id: compactArea

    x: root.compactLeft
    y: root.pillY + root.headerDrop
    width: root.compactWidth
    height: Theme.capsuleThickness
    opacity: (Notifs.bannerPhase === "compact" || Notifs.bannerPhase === "expanded") ? root.swapOpacity : 0

    Behavior on opacity {
      NumberAnimation {
        duration: 140
        easing.type: Easing.OutCubic
      }
    }

    Behavior on y {
      NumberAnimation {
        duration: 320
        easing.type: Easing.OutCubic
      }
    }

    Item {
      width: parent.width
      height: Math.max(summaryLabel.implicitHeight, appTag.implicitHeight)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        id: summaryLabel

        anchors.left: parent.left
        anchors.right: appTag.left
        anchors.rightMargin: Math.round(8 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        text: root.displayed !== null ? root.displayed.summary : ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        id: appTag

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Math.round(parent.width * 0.4))
        text: root.displayed !== null ? (root.count > 1 ? root.count + " new" : root.displayed.appName) : ""
        color: root.displayed !== null && root.displayed.urgency === NotificationUrgency.Critical ? Theme.red : Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.open && (Notifs.bannerPhase === "compact" || Notifs.bannerPhase === "expanded")
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: e => e.button === Qt.LeftButton ? (Notifs.bannerPhase === "compact" ? Notifs.expandBannerNow() : root.openNotifications()) : e.button === Qt.RightButton ? Notifs.dismissBannerSelected() : Notifs.dismissAll()
    }
  }

  Column {
    id: contentCol

    anchors.left: parent.left
    anchors.leftMargin: root.pad
    anchors.right: parent.right
    anchors.rightMargin: root.pad
    anchors.top: parent.top
    anchors.topMargin: root.pillY + Theme.capsuleThickness + root.pad
    spacing: Math.round(10 * Theme.scale)
    opacity: root.detailOpen ? root.swapOpacity : 0

    Behavior on opacity {
      NumberAnimation {
        duration: 140
        easing.type: Easing.OutCubic
      }
    }

    Item {
      width: parent.width
      height: Math.max(thumb.visible ? thumb.height : 0, bodyLabel.visible ? bodyLabel.implicitHeight : 0)
      visible: root.hasBody || root.hasImage

      Item {
        id: thumb

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasImage
        width: Math.round(56 * Theme.scale)
        height: width

        Item {
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: thumbMask
            maskSpreadAtMin: 1.0
            maskThresholdMin: 0.5
          }

          Image {
            id: thumbImage

            anchors.fill: parent
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            source: root.displayed !== null ? root.displayed.image : ""

            Timer {
              id: captureDelay

              interval: 300
              onTriggered: {
                if (root.displayed !== null && root.displayed.n) {
                  Notifs.captureAvatar(root.displayed.n, thumbImage)
                }
              }
            }

            onStatusChanged: {
              if (status !== Image.Ready || root.displayed === null || !root.displayed.n) {
                return
              }
              const key = Notifs.avatarKeyOf(root.displayed.n)
              if (key !== "" && !NotifStore.hasAvatar(key)) {
                captureDelay.restart()
              }
            }
          }
        }

        Rectangle {
          id: thumbMask

          anchors.fill: parent
          visible: false
          radius: Math.round(6 * Theme.scale)
          color: "white"
          antialiasing: true
          layer.enabled: true
        }
      }

      Text {
        id: bodyLabel

        anchors.left: thumb.visible ? thumb.right : parent.left
        anchors.leftMargin: thumb.visible ? Math.round(12 * Theme.scale) : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasBody
        text: root.displayed !== null ? root.displayed.body : ""
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        maximumLineCount: root.hasRows ? 3 : 6
        elide: Text.ElideRight
      }
    }

    Flow {
      width: parent.width
      spacing: Math.round(6 * Theme.scale)
      visible: root.actionCount > 0

      Repeater {
        model: root.actionCount

        delegate: BarButton {
          required property int modelData

          implicitHeight: Math.round(26 * Theme.scale)
          implicitWidth: actionLabel.implicitWidth + Math.round(16 * Theme.scale)
          fill: Theme.primary
          hoverFill: Qt.lighter(Theme.primary, 1.15)
          onClicked: root.invokeAction(modelData)

          Text {
            id: actionLabel

            anchors.centerIn: parent
            text: root.displayed !== null && root.displayed.actions.length > modelData ? root.displayed.actions[modelData] : ""
            color: Theme.onAccent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
          }
        }
      }
    }

    Column {
      width: parent.width
      spacing: Math.round(2 * Theme.scale)
      visible: root.hasRows

      Repeater {
        model: root.rows

        delegate: Item {
          id: rowItem

          required property var modelData
          required property int index

          width: contentCol.width
          height: Theme.bannerRowHeight
          opacity: 0

          function reveal() {
            rowItem.opacity = 0
            rowReveal.restart()
          }

          Component.onCompleted: rowItem.reveal()
          onModelDataChanged: rowItem.reveal()

          SequentialAnimation {
            id: rowReveal

            PauseAnimation {
              duration: rowItem.index * 30
            }

            NumberAnimation {
              target: rowItem
              property: "opacity"
              to: 1
              duration: 150
              easing.type: Easing.OutCubic
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius
            color: rowMouse.containsMouse ? Theme.surfaceHigh : "transparent"

            Behavior on color {
              ColorAnimation {
                duration: 100
              }
            }
          }

          Image {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: Math.round(6 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(19 * Theme.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: Quickshell.iconPath(AppIcons.forNotification(rowItem.modelData.snap.appIcon, rowItem.modelData.snap.desktopEntry, rowItem.modelData.snap.appName), "dialog-information")
          }

          Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: Math.round(8 * Theme.scale)
            anchors.right: rowDot.left
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(1 * Theme.scale)

            Text {
              width: parent.width
              text: rowItem.modelData.snap.appName
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: rowItem.modelData.snap.summary
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              elide: Text.ElideRight
            }
          }

          Rectangle {
            id: rowDot

            visible: rowItem.modelData.n.urgency === NotificationUrgency.Critical
            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(6 * Theme.scale)
            height: width
            radius: width / 2
            color: Theme.red
          }

          MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => e.button === Qt.LeftButton ? Notifs.selectBanner(rowItem.modelData) : rowItem.modelData.n.dismiss()
          }
        }
      }
    }

    Item {
      id: moreRow

      width: parent.width
      height: root.more > 0 ? Theme.bannerRowHeight : 0
      visible: root.more > 0
      opacity: 0

      Component.onCompleted: moreReveal.restart()
      onVisibleChanged: if (visible) {
        opacity = 0
        moreReveal.restart()
      }

      SequentialAnimation {
        id: moreReveal

        PauseAnimation {
          duration: root.rows.length * 30
        }

        NumberAnimation {
          target: moreRow
          property: "opacity"
          to: 1
          duration: 150
          easing.type: Easing.OutCubic
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Theme.rowRadius
        color: moreMouse.containsMouse ? Theme.surfaceHigh : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: 100
          }
        }
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(8 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        text: "+" + root.more + " more"
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
      }

      MouseArea {
        id: moreMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openNotifications()
      }
    }
  }
}
