import QtQuick

Item {
  id: root

  property var listView: null
  property var model: null
  property string keyRole: "key"
  property string rowObjectName: ""
  property int minTarget: -1
  property int maxTarget: -1
  property var flickable: null
  property real edgeZone: 48
  property real scrollSpeed: 6
  property var rowHeightAt: null

  property string dragKey: ""
  property int dragFrom: -1
  property int dragTarget: -1
  property real dragStartY: 0
  property real lastSceneY: 0
  property real scrollShift: 0
  property real dragDelta: 0
  property bool dragging: false
  property string settleKey: ""
  property real dropShift: 0
  property bool dropArmed: false
  property bool settling: false
  property bool suppressMove: false
  property bool snapPreview: false

  signal moved(string key, int target)

  Timer {
    id: edgeTimer

    interval: 16
    running: root.dragging && root.flickable !== null
    repeat: true
    onTriggered: root.scrollTick()
  }

  function scrollTick() {
    if (!root.dragging || !root.flickable) {
      return
    }
    const f = root.flickable
    const localY = root.lastSceneY - f.mapToItem(null, 0, 0).y
    let speed = 0
    if (localY < root.edgeZone) {
      const depth = 1 - Math.max(0, localY) / root.edgeZone
      speed = -root.scrollSpeed * depth * depth
    } else if (localY > f.height - root.edgeZone) {
      const depth = Math.min(1, (localY - (f.height - root.edgeZone)) / root.edgeZone)
      speed = root.scrollSpeed * depth * depth
    }
    if (speed === 0) {
      return
    }
    const max = Math.max(0, f.contentHeight - f.height)
    const next = Math.max(0, Math.min(max, f.contentY + speed))
    const applied = next - f.contentY
    if (applied === 0) {
      return
    }
    f.contentY = next
    root.scrollShift = root.scrollShift + applied
    root.dragDelta = root.dragDelta + applied
    const target = root.rowIndexAt(root.lastSceneY)
    if (target >= 0) {
      root.dragTarget = root.clampTarget(target)
    }
  }

  Behavior on dropShift {
    enabled: root.dropArmed
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  Timer {
    id: settleTimer

    interval: 240
    running: false
    repeat: false
    onTriggered: {
      root.settling = false
      root.settleKey = ""
      root.suppressMove = false
      root.snapPreview = false
    }
  }

  function indexOfKey(key) {
    if (!root.model) {
      return -1
    }
    for (let i = 0; i < root.model.count; i++) {
      if (String(root.model.get(i)[root.keyRole]) === String(key)) {
        return i
      }
    }
    return -1
  }

  function clampTarget(index) {
    let value = index
    if (root.maxTarget >= 0) {
      value = Math.min(value, root.maxTarget)
    }
    if (root.minTarget >= 0) {
      value = Math.max(value, root.minTarget)
    }
    return value
  }

  function rowIndexAt(sceneY) {
    if (!root.listView) {
      return -1
    }
    const kids = root.listView.contentItem.children
    for (let i = 0; i < kids.length; i++) {
      const child = kids[i]
      if (!child || child.objectName !== root.rowObjectName) {
        continue
      }
      const top = child.mapToItem(null, 0, 0).y
      if (sceneY >= top && sceneY < top + child.height) {
        return root.indexOfKey(child.dragKey)
      }
    }
    return -1
  }

  function begin(key, sceneY) {
    settleTimer.stop()
    root.settling = false
    root.settleKey = ""
    root.suppressMove = false
    root.snapPreview = false
    root.dropArmed = false
    root.dropShift = 0
    root.dragKey = key
    root.dragFrom = root.indexOfKey(key)
    root.dragTarget = root.dragFrom
    root.dragStartY = sceneY
    root.lastSceneY = sceneY
    root.scrollShift = 0
    root.dragDelta = 0
    root.dragging = true
  }

  function update(sceneY) {
    if (!root.dragging) {
      return
    }
    root.lastSceneY = sceneY
    const dragged = root.listView.itemAtIndex(root.dragFrom)
    const top = dragged ? dragged.y : 0
    const height = dragged ? dragged.height : 0
    const raw = sceneY - root.dragStartY + root.scrollShift
    root.dragDelta = Math.max(-top, Math.min(root.listView.contentHeight - top - height, raw))
    const target = root.rowIndexAt(sceneY)
    if (target >= 0) {
      root.dragTarget = root.clampTarget(target)
    }
  }

  function listSpacing() {
    return root.listView ? root.listView.spacing : 0
  }

  function movedTop(from, target) {
    const heights = []
    for (let i = 0; i < root.model.count; i++) {
      if (root.rowHeightAt) {
        heights.push(root.rowHeightAt(i))
        continue
      }
      const item = root.listView.itemAtIndex(i)
      heights.push(item ? item.height : 0)
    }
    if (from < 0 || from >= heights.length) {
      return 0
    }
    const seq = []
    for (let i = 0; i < heights.length; i++) {
      if (i !== from) {
        seq.push(heights[i])
      }
    }
    const at = Math.max(0, Math.min(seq.length, target))
    seq.splice(at, 0, heights[from])
    let top = 0
    for (let i = 0; i < at; i++) {
      top += seq[i]
    }
    return top + at * root.listSpacing()
  }

  function finish(commit) {
    if (!root.dragging) {
      return
    }
    const key = root.dragKey
    const target = root.dragTarget
    const from = root.dragFrom
    const changed = commit && key !== "" && target >= 0 && target !== from
    const dragged = root.listView.itemAtIndex(from)
    const visualY = (dragged ? dragged.y : 0) + root.dragDelta
    const newTop = changed ? root.movedTop(from, target) : (dragged ? dragged.y : 0)
    root.suppressMove = true
    root.snapPreview = changed
    if (changed) {
      root.moved(key, target)
    }
    root.dropArmed = false
    root.dropShift = visualY - newTop
    root.settleKey = key
    root.settling = true
    root.dragging = false
    root.dragKey = ""
    root.dragFrom = -1
    root.dragDelta = 0
    root.dragTarget = -1
    root.dropArmed = true
    root.dropShift = 0
    settleTimer.restart()
  }

  function end() {
    root.finish(true)
  }

  function cancel() {
    root.finish(false)
  }

  function previewOffset(index) {
    if (!root.dragging || root.dragFrom < 0 || root.dragTarget < 0 || root.dragFrom === root.dragTarget) {
      return 0
    }
    const dragged = root.listView.itemAtIndex(root.dragFrom)
    const shift = (dragged ? dragged.height : 0) + root.listSpacing()
    if (shift <= 0) {
      return 0
    }
    if (root.dragFrom < root.dragTarget && index > root.dragFrom && index <= root.dragTarget) {
      return -shift
    }
    if (root.dragFrom > root.dragTarget && index >= root.dragTarget && index < root.dragFrom) {
      return shift
    }
    return 0
  }

  function previewForKey(key) {
    return root.previewOffset(root.indexOfKey(key))
  }
}
