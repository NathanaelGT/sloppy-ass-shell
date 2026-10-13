import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

Rectangle {
  id: root

  property var group: null
  property bool expanded: false
  property bool appPinned: false
  property bool sectionVisible: true
  property bool animate: true
  property var routeStream: null
  property var targetFor: null
  property real maxVolume: 1.5
  property bool dragging: false
  property bool settling: false
  property real dragDelta: 0
  property real dropShift: 0
  property real previewShift: 0
  property bool snapPreview: false

  readonly property string dragKey: root.group ? root.group.name : ""

  signal toggleExpanded
  signal appPinToggled
  signal pinToggled(string key)
  signal routePressed(string key, var node, var anchor)
  signal wheeled(var node, real angleDelta)
  signal percentEditing(var editor)
  signal dragStarted(string key, real sceneY)
  signal dragMoved(real sceneY)
  signal dragEnded
  signal dragCancelled

  property var activePercentEditor: null

  function liveNode(viewKey) {
    const rows = root.group ? root.group.rows : []
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]
      if (row.separator !== true && row.viewKey === viewKey) {
        return row.node
      }
    }
    return null
  }

  ListModel {
    id: rowModel
  }

  function streamKids() {
    const out = []
    const kids = rowList.contentItem.children
    for (let i = 0; i < kids.length; i++) {
      if (kids[i] && kids[i].objectName === "streamRow") {
        out.push(kids[i])
      }
    }
    return out
  }

  function refreshPercentEditor() {
    let found = null
    const kids = root.streamKids()
    for (let i = 0; i < kids.length; i++) {
      const editor = kids[i].streamEditor
      if (editor && editor.editing) {
        found = editor
        break
      }
    }
    root.activePercentEditor = found
  }

  function cancelPercentEdits() {
    const kids = root.streamKids()
    for (let i = 0; i < kids.length; i++) {
      const editor = kids[i].streamEditor
      if (editor && editor.editing) {
        editor.cancel()
      }
    }
    root.activePercentEditor = null
  }

  function percentEditorAt(rowIndex) {
    let seen = -1
    let target = ""
    for (let i = 0; i < rowModel.count; i++) {
      const row = rowModel.get(i)
      if (row.separator) {
        continue
      }
      seen += 1
      if (seen === rowIndex) {
        target = row.rowKey
        break
      }
    }
    if (!target) {
      return null
    }
    const kids = root.streamKids()
    for (let i = 0; i < kids.length; i++) {
      if (kids[i].rowKey === target) {
        return kids[i].streamEditor
      }
    }
    return null
  }

  function viewKeyAt(rows, viewKey) {
    for (let j = 0; j < rows.length; j++) {
      const row = rows[j]
      if ((row.separator === true ? "__separator__" : row.viewKey) === viewKey) {
        return j
      }
    }
    return -1
  }

  function syncRows() {
    const rows = root.group ? root.group.rows : []
    for (let i = rowModel.count - 1; i >= 0; i--) {
      if (root.viewKeyAt(rows, rowModel.get(i).viewKey) < 0) {
        rowModel.remove(i)
      }
    }
    for (let j = 0; j < rows.length; j++) {
      const row = rows[j]
      const viewKey = row.separator === true ? "__separator__" : row.viewKey
      const rowKey = row.separator === true ? "__separator__" : row.key
      const kind = row.kind ? row.kind : ""
      const label = row.name ? row.name : ""
      const separator = row.separator === true
      let at = -1
      for (let i = 0; i < rowModel.count; i++) {
        if (rowModel.get(i).viewKey === viewKey) {
          at = i
          break
        }
      }
      if (at < 0) {
        rowModel.insert(j, {
          viewKey: viewKey,
          rowKey: rowKey,
          kind: kind,
          label: label,
          separator: separator
        })
      } else {
        if (at !== j) {
          rowModel.move(at, j, 1)
        }
        if (rowModel.get(j).rowKey !== rowKey) {
          rowModel.setProperty(j, "rowKey", rowKey)
        }
        if (rowModel.get(j).kind !== kind) {
          rowModel.setProperty(j, "kind", kind)
        }
        if (rowModel.get(j).label !== label) {
          rowModel.setProperty(j, "label", label)
        }
        if (rowModel.get(j).separator !== separator) {
          rowModel.setProperty(j, "separator", separator)
        }
      }
    }
  }

  onGroupChanged: root.syncRows()

  readonly property bool anyInputShown: {
    if (!root.group) {
      return false
    }
    for (let i = 0; i < root.group.inputs.length; i++) {
      if (root.streamRowShown(root.group.inputs[i].key, root.group.inputs[i].node)) {
        return true
      }
    }
    return false
  }
  readonly property bool anyOutputShown: {
    if (!root.group) {
      return false
    }
    for (let i = 0; i < root.group.outputs.length; i++) {
      if (root.streamRowShown(root.group.outputs[i].key, root.group.outputs[i].node)) {
        return true
      }
    }
    return false
  }
  readonly property bool hasStreams: root.group ? (root.group.inputs.length + root.group.outputs.length) > 0 : false
  readonly property bool hasContent: root.hasStreams
  readonly property bool hasPinned: {
    if (root.group && Pins.isAppPinned(root.group.name)) {
      return true
    }
    if (!root.group || !root.group.rows) {
      return false
    }
    const rows = root.group.rows
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].separator !== true && Pins.isStreamPinned(rows[i].key)) {
        return true
      }
    }
    return false
  }
  readonly property bool liveActive: {
    const rows = root.group ? root.group.rows : []
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]
      if (row.separator === true) {
        continue
      }
      if (Audio.streamActive(row.node)) {
        return true
      }
    }
    return false
  }

  function streamRowShown(key, node) {
    if (root.expanded) {
      return true
    }
    if (Pins.isStreamPinned(key)) {
      return true
    }
    return Audio.streamActive(node)
  }

  function rowShownAt(i) {
    const rows = root.group ? root.group.rows : []
    if (i < 0 || i >= rows.length) {
      return false
    }
    const row = rows[i]
    if (row.separator === true) {
      return root.anyInputShown && root.anyOutputShown
    }
    return root.streamRowShown(row.key, row.node)
  }

  function hasStreamAfter(key) {
    const rows = root.group ? root.group.rows : []
    let seen = false
    for (let j = 0; j < rows.length; j++) {
      const row = rows[j]
      if (!seen) {
        if (row.separator !== true && row.key === key) {
          seen = true
        }
        continue
      }
      if (row.separator === true) {
        if (root.anyInputShown && root.anyOutputShown) {
          return false
        }
      } else if (root.rowShownAt(j)) {
        return true
      }
    }
    return false
  }

  width: parent ? parent.width : 0
  height: ((root.expanded || root.hasPinned || root.liveActive) && root.hasContent) || (root.appPinned && root.sectionVisible && !root.hasContent) ? column.implicitHeight + Math.round(16 * Theme.scale) : 0
  opacity: (((root.expanded || root.hasPinned || root.liveActive) && root.hasContent) || (root.appPinned && root.sectionVisible && !root.hasContent) ? 1 : 0) * (root.dragging || root.settling ? 0.5 : 1)
  layer.enabled: root.dragging || root.settling
  radius: Theme.rowRadius
  color: Theme.surface
  antialiasing: true
  clip: true

  transform: [
    Translate {
      y: root.settling ? root.dropShift : (root.dragging ? root.dragDelta : 0)
    },
    Translate {
      y: root.dragging ? 0 : root.previewShift
      Behavior on y {
        enabled: !root.snapPreview
        NumberAnimation {
          duration: 180
          easing.type: Easing.OutCubic
        }
      }
    }
  ]

  Behavior on height {
    enabled: root.animate
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }
  Behavior on opacity {
    enabled: root.animate
    NumberAnimation {
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  Column {
    id: column

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Math.round(12 * Theme.scale)
    anchors.rightMargin: Math.round(12 * Theme.scale)
    anchors.topMargin: Math.round(8 * Theme.scale)
    spacing: 0

    Item {
      width: parent.width
      height: header.implicitHeight + Math.round(6 * Theme.scale)

      Row {
        id: header

        anchors.left: parent.left
        anchors.right: grip.left
        anchors.rightMargin: Math.round(4 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(6 * Theme.scale)

        Image {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(20 * Theme.scale)
          height: width
          sourceSize: Qt.size(width, height)
          source: Quickshell.iconPath(root.group ? root.group.icon : "", "application-x-executable")
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.group ? root.group.name : ""
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
        }

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: badge.implicitWidth + Math.round(10 * Theme.scale)
          height: Math.round(16 * Theme.scale)
          radius: height / 2
          color: Theme.surfaceHigh
          antialiasing: true

          Text {
            id: badge

            anchors.centerIn: parent
            text: root.group ? root.group.badge : ""
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
          }
        }
      }

      Rectangle {
        id: grip

        anchors.right: pinButton.left
        anchors.rightMargin: Math.round(2 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(20 * Theme.scale)
        height: width
        radius: width / 2
        color: gripMouse.containsMouse ? Theme.surfaceHigh : "transparent"
        antialiasing: true
        opacity: root.appPinned && root.sectionVisible ? 1 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }

        Icon {
          anchors.centerIn: parent
          name: "grip-vertical"
          color: root.dragging ? Theme.primary : Theme.overlay
          font.pixelSize: Theme.iconSize
        }

        MouseArea {
          id: gripMouse

          anchors.fill: parent
          enabled: root.appPinned && root.sectionVisible
          hoverEnabled: true
          cursorShape: Qt.OpenHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          preventStealing: true
          onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
              root.dragCancelled()
              return
            }
            root.dragStarted(root.dragKey, gripMouse.mapToItem(null, mouse.x, mouse.y).y)
          }
          onPositionChanged: mouse => root.dragMoved(gripMouse.mapToItem(null, mouse.x, mouse.y).y)
          onReleased: mouse => {
            if (mouse.button === Qt.LeftButton) {
              root.dragEnded()
            }
          }
          onCanceled: root.dragCancelled()
        }
      }

      IconButton {
        id: pinButton

        anchors.right: expandButton.left
        anchors.rightMargin: Math.round(2 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        size: Math.round(20 * Theme.scale)
        name: root.appPinned ? "pin-filled" : "pin"
        iconColor: root.appPinned ? Theme.primary : Theme.overlay
        opacity: root.sectionVisible ? 1 : 0
        enabled: root.sectionVisible
        onClicked: root.appPinToggled()

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }
      }

      IconButton {
        id: expandButton

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        size: Math.round(20 * Theme.scale)
        name: root.expanded ? "chevron-up" : "chevron-down"
        iconColor: Theme.overlay
        onClicked: root.toggleExpanded()
      }
    }

    Item {
      width: column.width
      height: rowList.contentHeight

      ListView {
        id: rowList

        anchors.fill: parent
        interactive: false
        focus: false
        clip: true
        model: rowModel
        cacheBuffer: 100000
        move: Transition {
          enabled: root.animate
          NumberAnimation {
            property: "y"
            duration: 220
            easing.type: Easing.OutCubic
          }
        }
        displaced: Transition {
          enabled: root.animate
          NumberAnimation {
            property: "y"
            duration: 220
            easing.type: Easing.OutCubic
          }
        }

        delegate: Item {
          id: rowItem

          objectName: "streamRow"

          required property string viewKey
          required property string rowKey
          required property string kind
          required property string label
          required property bool separator

          readonly property var node: root.liveNode(viewKey)

          readonly property bool pinned: !separator && Pins.isStreamPinned(rowKey)
          readonly property bool shown: separator ? (root.anyInputShown && root.anyOutputShown) : root.streamRowShown(rowKey, node)
          readonly property bool showDivider: !separator && shown && root.hasStreamAfter(rowKey)
          readonly property var streamEditor: streamRow.percentEditor

          width: rowList.width
          height: shown ? (separator ? Math.round(1 * Theme.scale) : streamRow.implicitHeight) + Math.round(12 * Theme.scale) : 0
          opacity: shown ? 1 : 0
          clip: true

          Behavior on height {
            enabled: root.animate
            NumberAnimation {
              duration: 220
              easing.type: Easing.OutCubic
            }
          }
          Behavior on opacity {
            enabled: root.animate
            NumberAnimation {
              duration: 160
              easing.type: Easing.OutCubic
            }
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(1 * Theme.scale)
            visible: rowItem.separator
            color: Theme.surfaceHigh
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(2 * Theme.scale)
            height: Math.round(1 * Theme.scale)
            visible: rowItem.showDivider
            color: Theme.surfaceHigh
          }

          AppStreamRow {
            id: streamRow

            visible: !rowItem.separator
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            node: rowItem.node
            kind: rowItem.kind
            label: rowItem.label
            target: root.targetFor ? root.targetFor(rowItem.node) : "Default"
            pinned: rowItem.pinned
            pinVisible: root.sectionVisible || root.expanded
            open: root.routeStream === rowItem.node
            active: Audio.streamActive(rowItem.node)
            maxVolume: root.maxVolume
            onPinToggled: root.pinToggled(rowItem.rowKey)
            onRoutePressed: anchor => root.routePressed(rowItem.rowKey, rowItem.node, anchor)
            onWheeled: angleDelta => root.wheeled(rowItem.node, angleDelta)
            onPercentEditing: editor => {
              if (editor) {
                root.activePercentEditor = editor
              } else {
                root.refreshPercentEditor()
              }
              root.percentEditing(root.activePercentEditor)
            }
          }
        }
      }
    }
  }
}
