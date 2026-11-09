import QtQuick
import QtQuick.Effects
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "notifications"
  align: "center"
  animateCardHeight: true
  animateCardWidth: true
  cardWidth: Panels.clusterWidth(root.screenId) + root.contentOuterPad * 2
  horizontalOffset: Panels.clusterRight(root.screenId) - Math.round((root.width - root.cardWidth) / 2) - root.cardWidth + root.contentOuterPad
  contentColor: Theme.capsuleHover
  contentOuterPad: 8
  contentInset: 18
  stemEnabled: true
  stemX: Panels.clusterRight(root.screenId) - Panels.clusterWidth(root.screenId)
  readonly property int budgetCount: 5
  readonly property real minCardHeight: Math.round(16 * Theme.scale) + Math.round(8 * Theme.scale) + Math.max(cardMetric.implicitHeight, Math.round(16 * Theme.scale)) + Math.round(20 * Theme.scale) + Math.round(8 * Theme.scale)
  property int measureRevision: 0

  readonly property var items: {
    const active = Notifs.active && Notifs.active.values ? Notifs.active.values : []
    const history = NotifStore.history
    const out = []
    for (let i = 0; i < active.length; i++) {
      const n = active[i]
      out.push({
        key: "a" + n.id,
        active: true,
        notification: n,
        sortId: Number(n.id) || 0,
        ts: Notifs.timeOf(n),
        appName: n.appName || "",
        appIcon: n.appIcon || "",
        desktopEntry: n.desktopEntry || "",
        summary: n.summary || "",
        body: n.body || "",
        actionTexts: n.actions ? n.actions.map(a => a.text) : [],
        imageSource: n.image || ""
      })
    }
    for (let i = 0; i < history.length; i++) {
      const e = history[i]
      out.push({
        key: "h" + e.id,
        active: false,
        id: e.id,
        sortId: Number(e.id) || 0,
        ts: e.ts,
        appName: e.appName || "",
        appIcon: e.appIcon || "",
        desktopEntry: e.desktopEntry || "",
        summary: e.summary || "",
        body: e.body || "",
        actionTexts: [],
        imageSource: "",
        hasImage: e.hasImage
      })
    }
    out.sort((a, b) => {
      if (a.ts !== b.ts) {
        return b.ts - a.ts
      }
      if (a.active !== b.active) {
        return a.active ? -1 : 1
      }
      return b.sortId - a.sortId
    })
    const labels = []
    for (let i = 0; i < out.length; i++) {
      labels.push(NotifStore.dayLabel(out[i].ts))
    }
    for (let i = 0; i < out.length; i++) {
      out[i].day = labels[i]
      out[i].firstInDay = i === 0 || labels[i] !== labels[i - 1]
      out[i].lastInDay = i === out.length - 1 || labels[i] !== labels[i + 1]
    }
    return out
  }

  readonly property var topCardHeights: {
    const revision = root.measureRevision
    const out = []
    for (let i = 0; i < root.budgetCount; i++) {
      const d = notificationList.itemAtIndex(i)
      out.push(d ? d.implicitHeight : root.minCardHeight)
    }
    return out
  }

  readonly property real listHeight: {
    if (root.items.length === 0) {
      return 0
    }
    if (root.items.length < root.budgetCount) {
      return root.minCardHeight * root.budgetCount + Theme.gap * (root.budgetCount - 1)
    }
    const heights = root.topCardHeights
    let sum = 0
    for (let i = 0; i < heights.length; i++) {
      sum += heights[i]
    }
    return sum + Theme.gap * (root.budgetCount - 1)
  }

  function timeLabel(ts) {
    return Qt.formatTime(new Date(ts * 1000), "HH:mm")
  }

  property bool undoArmed: false
  property bool restoring: false
  property bool clearing: false
  property int clearedFrom: 0
  property int closingCount: 0
  readonly property int clearSlideMs: 180
  readonly property int clearStagger: Math.round(clearSlideMs * 0.2)

  function clearAll() {
    if (root.clearing) {
      return
    }
    try {
      root.clearAllInner()
    } catch (e) {
      Notifs.lastError = "clearAll: " + String(e) + " | " + (e && e.stack ? e.stack : "")
      root.clearing = false
    }
  }

  function clearAllInner() {
    root.clearing = true
    const visible = []
    for (let i = 0; i < notificationList.count; i++) {
      const d = notificationList.itemAtIndex(i)
      if (!d || d.closing) {
        continue
      }
      const y = d.y - notificationList.contentY
      if (y + d.height > 0 && y < notificationList.height) {
        visible.push({
          d: d,
          y: y
        })
      }
    }
    visible.sort((a, b) => b.y - a.y)
    let lastDelay = 0
    for (let i = 0; i < visible.length; i++) {
      lastDelay = i * root.clearStagger
      visible[i].d.beginClear(lastDelay)
    }
    clearTimer.interval = lastDelay + root.clearSlideMs + 60
    clearTimer.restart()
  }

  function finalizeClear() {
    root.clearedFrom = Math.floor(Date.now() / 1000)
    Notifs.dismissAll()
    NotifStore.clearHistory()
    root.restoring = false
    root.undoArmed = true
    undoTimer.restart()
    root.clearing = false
  }

  function undoClear() {
    root.restoring = true
    undoTimer.stop()
    NotifStore.undoClear(root.clearedFrom, Math.floor(Date.now() / 1000), () => {
      root.restoring = false
      root.undoArmed = false
    })
  }

  onOpenChanged: {
    if (root.open) {
      NotifStore.markSeen()
      notifScroll.snap()
      notificationList.contentY = 0
    }
  }

  PanelHeader {
    title: "Notifications"

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "DND"
      color: Notifs.dnd ? Theme.yellow : Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      font.bold: Notifs.dnd
    }

    Switch {
      anchors.verticalCenter: parent.verticalCenter
      checked: Notifs.dnd
      track: Theme.surface
      onToggled: Notifs.dnd = !Notifs.dnd
    }

    Timer {
      id: undoTimer

      interval: 10000
      onTriggered: root.undoArmed = false
    }

    Timer {
      id: clearTimer

      interval: 0
      onTriggered: root.finalizeClear()
    }

    IconButton {
      size: Math.round(28 * Theme.scale)
      glyphSize: Theme.fontSize
      name: root.undoArmed ? "arrow-back-up" : "trash"
      iconColor: Theme.overlay
      bgColor: Theme.surface
      visible: root.items.length > 0 || root.undoArmed
      onClicked: {
        if (root.undoArmed && !root.restoring) {
          root.undoClear()
        } else if (!root.undoArmed) {
          root.clearAll()
        }
      }
    }
  }

  PlaceholderCard {
    shown: root.items.length === 0
    instant: Notifs.dnd
    icon: Notifs.dnd ? "bell-off" : "bell"
    text: !NotifStore.ready ? "Loading" : Notifs.dnd ? "Do not disturb" : "No notifications"
    rolling: !NotifStore.ready
  }

  Text {
    id: cardMetric

    visible: false
    text: "X"
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true
  }

  Item {
    width: root.contentInnerWidth
    height: root.listHeight

    ListView {
      id: notificationList
      visible: root.items.length > 0
      anchors.fill: parent
      model: root.items
      spacing: Theme.gap
      reuseItems: true
      clip: true
      cacheBuffer: Math.round(600 * Theme.scale)
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds

      onCountChanged: Qt.callLater(() => root.measureRevision += 1)

      onAtYEndChanged: {
        if (atYEnd && NotifStore.ready && !NotifStore.exhausted && !NotifStore.loadingMore && root.closingCount === 0) {
          NotifStore.loadMore()
        }
      }

      delegate: Column {
        id: notificationRow

        required property var modelData

        property bool closing: false
        property bool keepHeader: false
        property real collapse: 1
        property int clearDelay: 0
        property var closeTarget: null
        property bool closeDone: false
        property string itemKey: ""

        readonly property bool active: notificationRow.modelData.active
        readonly property bool thumbVisible: active ? String(modelData.imageSource || "").length > 0 : modelData.hasImage
        readonly property real headerSpace: dayHeader.visible ? dayHeader.height + spacing : 0

        function runCloseTarget() {
          if (closeDone || !closeTarget) {
            return
          }
          closeDone = true
          if (closeTarget.active) {
            closeTarget.notification.dismiss()
          } else {
            NotifStore.removeEntry(closeTarget.id)
          }
        }

        function resetRow() {
          closeAnim.stop()
          rowClearAnim.stop()
          notificationRow.runCloseTarget()
          if (closing) {
            root.closingCount -= 1
          }
          closing = false
          closeDone = false
          keepHeader = false
          collapse = 1
          closeTarget = null
          opacity = 1
          rowContent.opacity = 1
          notificationSlide.x = 0
          dayHeader.opacity = 1
          itemKey = modelData.key
          notificationRow.syncImage()
        }

        function beginClose(actionIndex) {
          if (closing || root.closingCount > 0 || root.clearing) {
            return
          }
          closing = true
          closeDone = false
          closeTarget = modelData
          keepHeader = modelData.firstInDay && !modelData.lastInDay
          root.closingCount += 1
          closeAnim.start()
          if (actionIndex >= 0 && active) {
            modelData.notification.actions[actionIndex].invoke()
          }
        }

        function beginClear(delay) {
          if (closing) {
            return
          }
          clearDelay = delay
          rowClearAnim.start()
        }

        function syncImage() {
          if (!modelData.active && modelData.hasImage) {
            NotifStore.requestImage(modelData.id)
          }
        }

        Component.onDestruction: {
          if (closing) {
            root.closingCount -= 1
          }
        }

        ListView.onPooled: {
          if (closing) {
            notificationRow.runCloseTarget()
            closing = false
            root.closingCount -= 1
          }
        }

        ListView.onReused: {
          notificationRow.resetRow()
          root.measureRevision += 1
        }

        Component.onCompleted: {
          notificationRow.itemKey = modelData.key
          notificationRow.syncImage()
          root.measureRevision += 1
        }

        onModelDataChanged: {
          if (notificationRow.itemKey === "" || notificationRow.itemKey === notificationRow.modelData.key) {
            notificationRow.syncImage()
            return
          }
          notificationRow.resetRow()
        }
        onImplicitHeightChanged: root.measureRevision += 1

        SequentialAnimation {
          id: rowClearAnim

          PauseAnimation {
            duration: notificationRow.clearDelay
          }

          ParallelAnimation {
            NumberAnimation {
              target: notificationSlide
              property: "x"
              to: notificationRow.width
              duration: root.clearSlideMs
              easing.type: Easing.InCubic
            }

            NumberAnimation {
              target: notificationRow
              property: "opacity"
              to: 0
              duration: root.clearSlideMs
              easing.type: Easing.InCubic
            }
          }
        }

        SequentialAnimation {
          id: closeAnim

          ParallelAnimation {
            NumberAnimation {
              target: notificationSlide
              property: "x"
              to: notificationRow.width
              duration: 180
              easing.type: Easing.InCubic
            }

            NumberAnimation {
              target: rowContent
              property: "opacity"
              to: 0
              duration: 180
              easing.type: Easing.InCubic
            }

            NumberAnimation {
              target: dayHeader
              property: "opacity"
              to: notificationRow.keepHeader ? 1 : 0
              duration: 180
              easing.type: Easing.InCubic
            }
          }

          NumberAnimation {
            target: notificationRow
            property: "collapse"
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
          }

          ScriptAction {
            script: notificationRow.runCloseTarget()
          }
        }

        width: notificationList.width
        height: closing ? (keepHeader ? headerSpace + collapse * (implicitHeight - headerSpace + notificationList.spacing) - notificationList.spacing : collapse * (implicitHeight + notificationList.spacing) - notificationList.spacing) : implicitHeight
        spacing: Math.round(8 * Theme.scale)

        SectionHeader {
          id: dayHeader

          visible: notificationRow.modelData ? notificationRow.modelData.firstInDay : false
          label: notificationRow.modelData ? notificationRow.modelData.day : ""
        }

        Column {
          id: rowContent

          transform: Translate {
            id: notificationSlide
          }

          width: parent.width
          spacing: Math.round(8 * Theme.scale)

          Item {
            width: parent.width
            height: Math.round(16 * Theme.scale)

            Image {
              id: appIcon

              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Math.round(16 * Theme.scale)
              height: width
              sourceSize: Qt.size(width, height)
              source: Quickshell.iconPath(AppIcons.forNotification(notificationRow.modelData.appIcon, notificationRow.modelData.desktopEntry, notificationRow.modelData.appName), "dialog-information")
            }

            Text {
              id: appName

              anchors.left: appIcon.right
              anchors.leftMargin: Math.round(6 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, parent.width - appIcon.width - Math.round(6 * Theme.scale) - appTime.width - Math.round(10 * Theme.scale))
              text: notificationRow.modelData.appName
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
              elide: Text.ElideRight
            }

            Text {
              id: appTime

              anchors.left: appName.right
              anchors.leftMargin: Math.round(10 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              text: root.timeLabel(notificationRow.modelData.ts)
              color: Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeSmall
            }
          }

          Rectangle {
            width: parent.width
            height: innerCol.implicitHeight + Math.round(20 * Theme.scale)
            radius: Math.round(12 * Theme.scale)
            color: Theme.base
            antialiasing: true

            HoverHandler {
              id: rowHover
            }

            Column {
              id: innerCol

              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Math.round(10 * Theme.scale)
              spacing: Math.round(6 * Theme.scale)

              Item {
                width: parent.width
                height: Math.max(thumb.visible ? thumb.height : 0, bodyText.implicitHeight, closeButton.height)

                Rectangle {
                  id: thumb

                  visible: notificationRow.thumbVisible
                  anchors.left: parent.left
                  anchors.top: parent.top
                  width: Math.round(44 * Theme.scale)
                  height: width
                  radius: Math.round(10 * Theme.scale)
                  color: Theme.surfaceHigh
                  clip: true

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
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      source: notificationRow.active ? notificationRow.modelData.imageSource : NotifStore.imageUrlFor(notificationRow.modelData.id)
                      visible: notificationRow.active || source !== ""
                    }
                  }

                  Rectangle {
                    id: thumbMask

                    anchors.fill: parent
                    visible: false
                    radius: thumb.radius
                    color: "white"
                    antialiasing: true
                    layer.enabled: true
                  }

                  Spinner {
                    anchors.centerIn: parent
                    visible: !notificationRow.active && NotifStore.imageUrlFor(notificationRow.modelData.id) === ""
                    running: visible
                  }
                }

                Column {
                  id: bodyText

                  anchors.left: thumb.visible ? thumb.right : parent.left
                  anchors.leftMargin: thumb.visible ? Math.round(10 * Theme.scale) : 0
                  anchors.right: closeButton.left
                  anchors.rightMargin: Math.round(4 * Theme.scale)
                  anchors.top: parent.top
                  spacing: Math.round(2 * Theme.scale)

                  Text {
                    width: parent.width
                    text: notificationRow.modelData.summary
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    visible: text.length > 0
                    text: notificationRow.modelData.body
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    maximumLineCount: notificationRow.active ? 3 : 2
                    elide: Text.ElideRight
                  }
                }

                IconButton {
                  id: closeButton

                  anchors.right: parent.right
                  anchors.top: parent.top
                  size: Math.round(16 * Theme.scale)
                  glyphSize: Theme.fontSizeSmall
                  name: "x"
                  iconColor: Theme.overlay
                  opacity: notificationRow.active ? 1 : (rowHover.hovered ? 1 : 0)
                  onClicked: notificationRow.beginClose(-1)
                }
              }

              Row {
                visible: notificationRow.active && notificationRow.modelData.actionTexts.length > 0
                spacing: Math.round(6 * Theme.scale)

                Repeater {
                  model: Math.min(3, notificationRow.modelData.actionTexts.length)

                  delegate: BarButton {
                    required property int modelData

                    implicitWidth: actionLabel.implicitWidth + Math.round(16 * Theme.scale)
                    onClicked: notificationRow.beginClose(modelData)
                    Text {
                      id: actionLabel

                      anchors.centerIn: parent
                      text: notificationRow.modelData.actionTexts[modelData]
                      color: Theme.text
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSizeSmall
                    }
                  }
                }
              }
            }
          }
        }
      }

      TopCutCorners {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: notificationList.contentY > 0
        color: root.contentColor
        z: 100
      }
    }

    SmoothScroll {
      id: notifScroll

      target: notificationList
      anchors.fill: notificationList
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      onWheel: event => {
        notifScroll.wheel(event)
        event.accepted = true
      }
    }
  }
}
