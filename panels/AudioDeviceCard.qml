import QtQuick
import "../theme"
import "../components"
import "../services"

Item {
  id: root

  property string kind: "output"
  property var devices: []
  property bool showAll: false
  property real maxVolume: 1.5

  signal setDefault(var node)
  signal togglePin(string name)
  signal wheeled(var node, real angleDelta)
  signal reordered(string name, int target)

  DragReorder {
    id: dragger

    listView: deviceList
    model: deviceModel
    keyRole: "key"
    rowObjectName: "deviceRow"
    onMoved: (key, target) => root.reordered(key, target)
  }

  property var activeEditor: null
  property var nameEditors: []
  property var activePercentEditor: null
  property var percentEditors: []

  ListModel {
    id: deviceModel
  }

  function syncDevices() {
    const devices = root.devices;
    for (let i = deviceModel.count - 1; i >= 0; i--) {
      const key = deviceModel.get(i).key;
      let found = false;
      for (let j = 0; j < devices.length; j++) if (devices[j].name === key) {
        found = true;
        break;
      }
      if (!found) deviceModel.remove(i);
    }
    for (let j = 0; j < devices.length; j++) {
      const entry = devices[j];
      const key = entry.name;
      let at = -1;
      for (let i = 0; i < deviceModel.count; i++) if (deviceModel.get(i).key === key) {
        at = i;
        break;
      }
      if (at < 0) {
        deviceModel.insert(j, { key: key, present: entry.present === true, current: entry.current === true, pinned: entry.pinned === true, sticky: entry.sticky === true, dormant: entry.dormant === true, monitored: entry.monitored === true });
      } else {
        if (at !== j) deviceModel.move(at, j, 1);
        if (deviceModel.get(j).present !== (entry.present === true)) deviceModel.setProperty(j, "present", entry.present === true);
        if (deviceModel.get(j).current !== (entry.current === true)) deviceModel.setProperty(j, "current", entry.current === true);
        if (deviceModel.get(j).pinned !== (entry.pinned === true)) deviceModel.setProperty(j, "pinned", entry.pinned === true);
        if (deviceModel.get(j).sticky !== (entry.sticky === true)) deviceModel.setProperty(j, "sticky", entry.sticky === true);
        if (deviceModel.get(j).dormant !== (entry.dormant === true)) deviceModel.setProperty(j, "dormant", entry.dormant === true);
        if (deviceModel.get(j).monitored !== (entry.monitored === true)) deviceModel.setProperty(j, "monitored", entry.monitored === true);
      }
    }
  }

  onDevicesChanged: root.syncDevices()

  function registerEditor(editor, key) {
    const next = root.nameEditors.slice();
    next.push({ editor: editor, key: key });
    root.nameEditors = next;
  }

  function unregisterEditor(editor) {
    root.nameEditors = root.nameEditors.filter((entry) => entry.editor !== editor);
  }

  function findNameEditor(displayText) {
    for (let i = 0; i < root.nameEditors.length; i++) if (root.nameEditors[i].editor.text === displayText) return root.nameEditors[i].editor;
    return null;
  }

  function testNodeName(displayText) {
    for (let i = 0; i < root.nameEditors.length; i++) if (root.nameEditors[i].editor.text === displayText) return root.nameEditors[i].key;
    return "";
  }

  function registerPercentEditor(editor, key) {
    const next = root.percentEditors.slice();
    next.push({ editor: editor, key: key });
    root.percentEditors = next;
  }

  function unregisterPercentEditor(editor) {
    root.percentEditors = root.percentEditors.filter((entry) => entry.editor !== editor);
  }

  function findPercentEditor(nodeName) {
    for (let i = 0; i < root.percentEditors.length; i++) if (root.percentEditors[i].key === nodeName) return root.percentEditors[i].editor;
    return null;
  }

  function cancelEdit() {
    const editor = root.activeEditor;
    root.activeEditor = null;
    if (editor) editor.cancel();
    const percentEditor = root.activePercentEditor;
    root.activePercentEditor = null;
    if (percentEditor) percentEditor.cancel();
  }

  function nodeFor(key) {
    for (let i = 0; i < root.devices.length; i++) if (root.devices[i].name === key) return root.devices[i].node;
    return null;
  }

  implicitHeight: cardColumn.implicitHeight + Math.round(16 * Theme.scale)

  MouseArea {
    anchors.fill: parent
    enabled: dragger.dragging
    acceptedButtons: Qt.RightButton
    z: 10
    onPressed: (mouse) => {
      if (mouse.button === Qt.RightButton) dragger.cancel();
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.cardRadius
    color: Theme.surface
    antialiasing: true

    Column {
      id: cardColumn

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Math.round(12 * Theme.scale)
      anchors.rightMargin: Math.round(12 * Theme.scale)
      anchors.topMargin: Math.round(8 * Theme.scale)
      spacing: 0

      Item {
        width: cardColumn.width
        height: deviceList.contentHeight

        ListView {
          id: deviceList

          anchors.fill: parent
          interactive: false
          focus: false
          clip: !dragger.dragging
          model: deviceModel
          cacheBuffer: 100000
          move: Transition { enabled: !dragger.suppressMove; NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }
          displaced: Transition { enabled: !dragger.suppressMove; NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }

          delegate: Item {
            id: entry

            objectName: "deviceRow"

            required property string key
            required property bool present
            required property bool current
            required property bool pinned
            required property bool sticky
            required property bool dormant
            required property bool monitored

            readonly property var node: root.nodeFor(entry.key)
            readonly property bool shown: current || ((pinned || sticky) && present) || root.showAll
            readonly property string dragKey: entry.key
            readonly property bool dragging: dragger.dragging && dragger.dragKey === entry.key
            readonly property bool settling: dragger.settling && dragger.settleKey === entry.key
            readonly property string label: entry.node ? Aliases.displayName(entry.node) : (Aliases.aliasFor(entry.key) || entry.key)
            readonly property var audio: entry.node ? entry.node.audio : null

            width: deviceList.width
          height: shown ? entryColumn.implicitHeight + Math.round(6 * Theme.scale) : 0
          opacity: shown ? 1 : 0
          z: entry.dragging || entry.settling ? 2 : 0

          Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

          Item {
            anchors.fill: parent
            anchors.leftMargin: -Math.round(8 * Theme.scale)
            anchors.rightMargin: -Math.round(8 * Theme.scale)
            clip: true
            opacity: entry.present && !entry.dormant && !entry.dragging && !entry.settling ? 1 : 0.5
            layer.enabled: !entry.present || entry.dormant || entry.dragging || entry.settling
            transform: [
              Translate { y: entry.settling ? dragger.dropShift : (entry.dragging ? dragger.dragDelta : 0) },
              Translate {
                y: entry.dragging ? 0 : dragger.previewForKey(entry.key)
                Behavior on y {
                  enabled: !dragger.snapPreview
                  NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
              }
            ]

            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Column {
              id: entryColumn

              anchors.left: parent.left
              anchors.leftMargin: Math.round(8 * Theme.scale)
              anchors.right: parent.right
              anchors.rightMargin: Math.round(8 * Theme.scale)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Math.round(2 * Theme.scale)

              Item {
                width: parent.width
                height: Math.round(20 * Theme.scale)

                Rectangle {
                  id: grip

                  anchors.right: pinButton.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.round(20 * Theme.scale)
                  height: parent.height
                  radius: width / 2
                  color: gripMouse.containsMouse ? Theme.surfaceHigh : "transparent"
                  antialiasing: true
                  opacity: root.showAll ? 1 : 0

                  Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                  Icon {
                    id: gripIcon

                    anchors.centerIn: parent
                    name: "grip-vertical"
                    color: entry.dragging ? Theme.primary : Theme.overlay
                    font.pixelSize: Theme.iconSize
                  }

                  MouseArea {
                    id: gripMouse

                    anchors.fill: parent
                    enabled: root.showAll
                    hoverEnabled: true
                    cursorShape: Qt.OpenHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    preventStealing: true
                    onPressed: (mouse) => {
                      if (mouse.button === Qt.RightButton) {
                        if (dragger.dragging) dragger.cancel();
                        return;
                      }
                      dragger.begin(entry.key, gripMouse.mapToItem(null, mouse.x, mouse.y).y);
                    }
                    onPositionChanged: (mouse) => dragger.update(gripMouse.mapToItem(null, mouse.x, mouse.y).y)
                    onReleased: (mouse) => {
                      if (mouse.button === Qt.LeftButton) dragger.end();
                    }
                    onCanceled: dragger.cancel()
                  }
                }

                EditableLabel {
                  id: nameEditor

                  anchors.left: parent.left
                  anchors.right: grip.left
                  anchors.rightMargin: Math.round(22 * Theme.scale)
                  anchors.verticalCenter: parent.verticalCenter
                  text: entry.label
                  color: entry.dormant ? Theme.overlay : entry.current ? Theme.primary : Theme.text
                  bold: true
                  onEdited: (value) => Aliases.setAlias(entry.key, value)
                  onEditingChanged: {
                    if (editing) root.activeEditor = nameEditor;
                    else if (root.activeEditor === nameEditor) root.activeEditor = null;
                  }
                  Component.onDestruction: {
                    if (root.activeEditor === nameEditor) root.activeEditor = null;
                    root.unregisterEditor(nameEditor);
                  }
                  Component.onCompleted: root.registerEditor(nameEditor, entry.key)
                }

                IconButton {
                  id: pinButton

                  anchors.right: defaultButton.left
                  anchors.rightMargin: Math.round(2 * Theme.scale)
                  anchors.verticalCenter: parent.verticalCenter
                  size: Math.round(20 * Theme.scale)
                  visible: root.showAll || pinButton.opacity > 0
                  opacity: root.showAll ? 1 : 0
                  name: entry.pinned ? "pin-filled" : "pin"
                  iconColor: entry.pinned ? Theme.primary : Theme.overlay
                  onClicked: root.togglePin(entry.key)

                  Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                IconButton {
                  id: defaultButton

                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  size: Math.round(20 * Theme.scale)
                  visible: entry.present
                  name: entry.current ? "check" : "circle"
                  iconColor: entry.current ? Theme.primary : Theme.overlay
                  onClicked: root.setDefault(entry.node)
                }
              }

              Row {
                width: parent.width
                visible: entry.present
                spacing: Math.round(6 * Theme.scale)

                Slider {
                  width: parent.width - Math.round(64 * Theme.scale)
                  anchors.verticalCenter: parent.verticalCenter
                  node: entry.monitored ? entry.node : null
                  value: entry.audio ? entry.audio.volume / root.maxVolume : 0
                  fullMark: 1 / root.maxVolume
                  onMoved: (v) => {
                    if (entry.audio) entry.audio.volume = v * root.maxVolume;
                    if (root.kind === "output" && entry.audio && !entry.audio.muted) Audio.playVolumeFeedback(entry.audio.volume);
                  }
                  onWheeled: (angleDelta) => {
                    root.wheeled(entry.node, angleDelta);
                    if (root.kind === "output" && entry.audio && !entry.audio.muted) Audio.playVolumeFeedback(entry.audio.volume);
                  }
                }

                EditablePercent {
                  id: percentEditor

                  anchors.verticalCenter: parent.verticalCenter
                  percent: entry.audio ? entry.audio.volume * 100 : 0
                  maximum: root.maxVolume * 100
                  onEdited: (value) => {
                    if (entry.audio) entry.audio.volume = value / 100;
                    if (root.kind === "output" && entry.audio && !entry.audio.muted) Audio.playVolumeFeedback(entry.audio.volume);
                  }
                  onWheeled: (angleDelta) => root.wheeled(entry.node, angleDelta)
                  onEditingChanged: {
                    if (editing) root.activePercentEditor = percentEditor;
                    else if (root.activePercentEditor === percentEditor) root.activePercentEditor = null;
                  }
                  Component.onDestruction: {
                    if (root.activePercentEditor === percentEditor) root.activePercentEditor = null;
                    root.unregisterPercentEditor(percentEditor);
                  }
                  Component.onCompleted: root.registerPercentEditor(percentEditor, entry.key)
                }

                MuteButton {
                  anchors.verticalCenter: parent.verticalCenter
                  kind: root.kind
                  muted: entry.audio ? entry.audio.muted : false
                  dormant: entry.dormant
                  level: entry.audio ? entry.audio.volume : 0
                  maxLevel: root.maxVolume
                  onClicked: {
                    if (entry.audio) entry.audio.muted = !entry.audio.muted;
                    if (root.kind === "output" && entry.audio && !entry.audio.muted) Audio.playVolumeFeedback(entry.audio.volume);
                  }
                  onWheeled: (angleDelta) => {
                    root.wheeled(entry.node, angleDelta);
                    if (root.kind === "output" && entry.audio && !entry.audio.muted) Audio.playVolumeFeedback(entry.audio.volume);
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
}
