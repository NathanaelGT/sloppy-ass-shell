import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "music"
  align: "center"
  animateCardWidth: true
  animateCardHeight: true
  cardWidth: Panels.clusterWidth(root.screenId) + root.contentOuterPad * 2
  horizontalOffset: Panels.clusterRight(root.screenId) - Math.round((root.width - root.cardWidth) / 2) - root.cardWidth + root.contentOuterPad
  contentOuterPad: 8
  contentInset: 18
  contentColor: Theme.capsuleHover
  stemEnabled: true
  stemRight: true
  stemX: Panels.clusterRight(root.screenId) - Theme.capsuleThickness
  popupOpen: routePopup.opened
  cancelItem: root.activeEditor
  onCancelRequested: {
    if (root.activeEditor) {
      root.activeEditor.cancel()
    }
  }

  readonly property var song: Mpd.song
  readonly property bool playing: Mpd.state === "play"
  readonly property real seekFraction: Mpd.duration > 0 ? Math.max(0, Math.min(1, Mpd.elapsed / Mpd.duration)) : 0
  property bool seeking: false
  property real seekPreview: 0
  property int currentTab: Mpd.lastTab
  property string browsePath: ""
  property var searchResults: []
  property int searchSeq: 0
  property bool searchPending: false
  property string searchText: ""
  property int navDirection: 1
  property var activeEditor: null
  readonly property bool bulkQueueSync: queueModel.count > 150

  onSearchTextChanged: {
    searchTimer.stop()
    if (root.searchText.trim().length > 0 && !(root.browsePath === "pinned" || root.browsePath === "favorites")) {
      searchTimer.restart()
    } else {
      root.searchResults = []
      root.searchPending = false
    }
  }

  function s(n) {
    return Math.round(n * Theme.scale)
  }

  function matchesSearch(title, artist) {
    const q = root.searchText.trim().toLowerCase()
    if (q.length === 0) {
      return true
    }
    return (title || "").toLowerCase().indexOf(q) >= 0 || (artist || "").toLowerCase().indexOf(q) >= 0
  }

  function queueRowHeight(i) {
    const row = queueModel.get(i)
    if (!row || !root.matchesSearch(row.title, row.artist)) {
      return 0
    }
    return s(44) + s(4)
  }
  function hairline() {
    return Math.max(1, Math.round(Theme.scale))
  }

  function fmtTime(seconds) {
    return Mpd.fmtTime(seconds)
  }

  function previewSeek(fraction) {
    const clamped = Math.max(0, Math.min(1, fraction))
    if (Mpd.duration <= 0) {
      return
    }
    root.seeking = true
    root.seekPreview = clamped
    seekCommitTimer.restart()
  }

  function commitSeek() {
    if (!root.seeking) {
      return
    }
    root.seeking = false
    Mpd.seek(root.seekPreview * Mpd.duration)
  }

  function wheelSeek(delta) {
    if (Mpd.duration <= 0) {
      return
    }
    Mpd.seek(Mpd.elapsed + (delta > 0 ? 1 : -1) * 5)
  }

  function wheelVolume(delta) {
    Mpd.setVolume(Mpd.displayVolume + (delta > 0 ? 2 : -2))
  }

  function switchTab(i) {
    root.currentTab = i
    Mpd.lastTab = i
    Mpd.saveState()
  }

  function testQueueState() {
    const rows = []
    for (let i = 0; i < queueModel.count; i++) {
      const q = queueModel.get(i)
      const del = queueList.itemAtIndex(i)
      rows.push({
        qid: q.qid,
        pos: q.pos,
        title: q.title,
        revealed: del ? !!del.rowCard.revealed : false
      })
    }
    return {
      open: root.open,
      currentId: Mpd.song ? Mpd.song.id : -1,
      scrollY: Math.round(queueList.contentY),
      maxScrollY: Math.round(Math.max(0, queueList.contentHeight - queueList.height)),
      viewportY: Math.round(queueList.mapToItem(null, 0, 0).y),
      viewportHeight: Math.round(queueList.height),
      rows: rows
    }
  }

  function testQueueDragHold(from, to) {
    if (from < 0 || from >= queueModel.count || to < 0 || to >= queueModel.count || from === to) {
      return {
        reason: "bad args"
      }
    }
    const fromItem = queueList.itemAtIndex(from)
    const toItem = queueList.itemAtIndex(to)
    if (!fromItem || !toItem) {
      return {
        reason: "no item"
      }
    }
    const y1 = fromItem.mapToItem(null, 0, fromItem.height / 2).y
    const y2 = toItem.mapToItem(null, 0, toItem.height / 2).y
    queueDragger.begin(fromItem.dragKey, y1)
    queueDragger.update(y1 + (y2 - y1) / 2)
    queueDragger.update(y2)
    return {
      key: fromItem.dragKey,
      y1: y1,
      y2: y2,
      dragFrom: queueDragger.dragFrom,
      dragTarget: queueDragger.dragTarget,
      rawTarget: queueDragger.rowIndexAt(y2)
    }
  }

  function testQueueDrag(from, to) {
    const diag = testQueueDragHold(from, to)
    if (diag.dragFrom !== undefined) {
      queueDragger.end()
    }
    return diag
  }

  function testQueueDrop() {
    queueDragger.end()
  }

  function testQueueDragEdge(edge) {
    const top = queueList.mapToItem(null, 0, 0).y
    if (edge === "top") {
      queueDragger.update(top + 5)
    } else {
      queueDragger.update(top + queueList.height - 5)
    }
  }

  function testQueueDragUpdate(y) {
    queueDragger.update(y)
  }

  function testQueueCancel() {
    queueDragger.cancel()
    queueList.contentY = 0
  }

  function testControlRects(index) {
    const del = queueList.itemAtIndex(index === undefined ? 0 : index)
    if (!del) {
      return null
    }
    function find(item, name) {
      for (let i = 0; i < item.children.length; i++) {
        const c = item.children[i]
        if (c.objectName === name) {
          return c
        }
        const deep = find(c, name)
        if (deep) {
          return deep
        }
      }
      return null
    }
    const out = {}
    const names = ["queueGrip"]
    for (let i = 0; i < names.length; i++) {
      const it = find(del, names[i])
      if (!it || !it.visible) {
        out[names[i]] = null
        continue
      }
      const p = it.mapToItem(null, it.width / 2, it.height / 2)
      out[names[i]] = {
        x: Math.round(p.x),
        y: Math.round(p.y)
      }
    }
    return out
  }

  function syncQueueModel() {
    const items = Mpd.queue
    for (let i = queueModel.count - 1; i >= 0; i--) {
      const qid = queueModel.get(i).qid
      let found = false
      for (let j = 0; j < items.length; j++) {
        if (items[j].id === qid) {
          found = true
          break
        }
      }
      if (!found) {
        queueModel.remove(i)
      }
    }
    for (let j = 0; j < items.length; j++) {
      const q = items[j]
      let at = -1
      for (let i = 0; i < queueModel.count; i++) {
        if (queueModel.get(i).qid === q.id) {
          at = i
          break
        }
      }
      if (at < 0) {
        queueModel.insert(j, {
          qid: q.id,
          pos: q.pos,
          file: q.file,
          title: q.title,
          artist: q.artist,
          duration: q.duration
        })
      } else {
        if (at !== j) {
          queueModel.move(at, j, 1)
        }
        const row = queueModel.get(j)
        if (row.pos !== q.pos) {
          queueModel.setProperty(j, "pos", q.pos)
        }
        if (row.file !== q.file) {
          queueModel.setProperty(j, "file", q.file)
        }
        if (row.title !== q.title) {
          queueModel.setProperty(j, "title", q.title)
        }
        if (row.artist !== q.artist) {
          queueModel.setProperty(j, "artist", q.artist)
        }
        if (row.duration !== q.duration) {
          queueModel.setProperty(j, "duration", q.duration)
        }
      }
    }
  }

  readonly property bool inCollection: root.browsePath === "pinned" || root.browsePath === "favorites"
  readonly property bool searching: root.searchText.trim().length > 0

  function dirEntries(path) {
    const folder = Mpd.folders[path]
    return folder && folder.entries ? folder.entries : []
  }

  readonly property var currentDirEntries: root.inCollection ? [] : root.dirEntries(root.browsePath)

  readonly property var collectionEntries: root.inCollection ? Mpd.collectionEntries(root.browsePath === "pinned" ? Mpd.pinned : Mpd.favorites) : []

  readonly property var collectionRows: root.searching || root.browsePath.length > 0 ? [] : [
    {
      kind: "pinned",
      path: "pinned",
      label: "Pinned"
    },
    {
      kind: "favorites",
      path: "favorites",
      label: "Favorites"
    }
  ]

  readonly property var folderRows: root.searching || root.inCollection ? [] : root.currentDirEntries.filter(e => e.type === "dir")

  readonly property var trackRows: {
    if (root.searching) {
      if (root.inCollection) {
        const q = root.searchText.trim().toLowerCase()
        return root.collectionEntries.filter(e => root.matchesQuery(e, q))
      }
      return root.searchResults
    }
    if (root.inCollection) {
      return root.collectionEntries
    }
    return root.currentDirEntries.filter(e => e.type === "file")
  }

  function matchesQuery(entry, q) {
    return (entry.title || "").toLowerCase().indexOf(q) >= 0 || (entry.artist || "").toLowerCase().indexOf(q) >= 0
  }

  function isAncestorOf(ancestor, path) {
    if (ancestor.length === 0) {
      return true
    }
    return path.indexOf(ancestor + "/") === 0
  }

  function backPath() {
    const idx = root.browsePath.lastIndexOf("/")
    return idx > 0 ? root.browsePath.slice(0, idx) : ""
  }

  function goTo(path) {
    if (path === root.browsePath) {
      return
    }
    root.navDirection = root.isAncestorOf(path, root.browsePath) ? -1 : 1
    root.browsePath = path
    root.searchResults = []
    root.searchPending = false
    searchTimer.stop()
    root.loadPath()
    if (root.searching) {
      root.runSearch()
    }
    foldersFlick.contentY = 0
    foldersColumn.x = root.navDirection > 0 ? foldersFlick.width : -foldersFlick.width
    navAnim.to = 0
    navAnim.restart()
  }

  function loadPath() {
    if (root.inCollection) {
      Mpd.loadAllSongs(() => {})
      return
    }
    Mpd.lsdir(root.browsePath, () => {})
    Mpd.fetchCount(root.browsePath, () => {})
  }

  readonly property var breadcrumb: {
    const segs = [
      {
        path: "",
        label: "Music"
      }
    ]
    if (root.inCollection) {
      segs.push({
        path: root.browsePath,
        label: root.browsePath === "pinned" ? "Pinned" : "Favorites"
      })
      return segs
    }
    if (root.browsePath.length === 0) {
      return segs
    }
    const parts = root.browsePath.split("/")
    let cur = ""
    for (let i = 0; i < parts.length; i++) {
      cur = cur.length > 0 ? cur + "/" + parts[i] : parts[i]
      segs.push({
        path: cur,
        label: parts[i]
      })
    }
    return segs
  }

  function playRowPath(path) {
    if (path === "pinned") {
      Mpd.playPinned()
    } else if (path === "favorites") {
      Mpd.playFavorites()
    } else {
      Mpd.playFolder(path)
    }
  }

  function playCurrent() {
    if (root.searching) {
      const uris = root.trackRows.map(e => e.path)
      if (uris.length > 0) {
        Mpd.playTracks(uris, root.browsePath, "")
      }
      return
    }
    if (root.browsePath.length === 0) {
      Mpd.playAll()
      return
    }
    root.playRowPath(root.browsePath)
  }

  function playSearchFrom(entry) {
    const uris = root.trackRows.map(e => e.path)
    Mpd.playTracks(uris, root.browsePath, entry.path)
  }

  function metaText() {
    if (root.searching) {
      return root.trackRows.length + " tracks"
    }
    if (root.inCollection) {
      return root.collectionEntries.length + " tracks"
    }
    const c = Mpd.counts[root.browsePath]
    if (c) {
      return c.songs + " tracks · " + Mpd.fmtTime(c.playtime)
    }
    return ""
  }

  function playLabel() {
    if (root.searching) {
      return "Play results"
    }
    if (root.browsePath.length === 0) {
      return "Play all"
    }
    if (root.inCollection) {
      return root.browsePath === "pinned" ? "Play Pinned" : "Play Favorites"
    }
    return "Play folder"
  }

  function runSearch() {
    const q = root.searchText.trim()
    root.searchSeq = root.searchSeq + 1
    const tag = root.searchSeq
    if (q.length === 0 || root.inCollection) {
      root.searchResults = []
      root.searchPending = false
      return
    }
    root.searchPending = true
    Mpd.searchSubtree(root.browsePath, q, entries => {
      if (tag !== root.searchSeq) {
        return
      }
      root.searchPending = false
      root.searchResults = entries
    })
  }

  function testFolderState() {
    const rows = []
    for (let i = 0; i < root.collectionRows.length; i++) {
      rows.push({
        kind: root.collectionRows[i].kind,
        path: root.collectionRows[i].path,
        label: root.collectionRows[i].label
      })
    }
    for (let i = 0; i < root.folderRows.length; i++) {
      rows.push({
        kind: "dir",
        path: root.folderRows[i].path,
        label: root.folderRows[i].name
      })
    }
    const tracks = root.trackRows
    for (let i = 0; i < tracks.length; i++) {
      rows.push({
        kind: "file",
        path: tracks[i].path,
        label: tracks[i].title || tracks[i].name
      })
    }
    return {
      open: root.open,
      tab: root.currentTab,
      path: root.browsePath,
      search: root.searchText,
      searching: root.searching,
      pending: root.searchPending,
      breadcrumb: root.breadcrumb,
      meta: root.metaText(),
      rows: rows
    }
  }

  function testFolderNavigate(path) {
    if (path === "back") {
      root.goTo(root.backPath())
    } else {
      root.goTo(path)
    }
    return true
  }

  function testFolderSearch(query) {
    root.searchText = query
    searchTimer.stop()
    root.runSearch()
    return true
  }

  function testFolderRowRect(index) {
    let del = null
    const nCol = collectionRepeater.count
    const nDir = folderRepeater.count
    if (index < nCol) {
      del = collectionRepeater.itemAt(index)
    } else if (index < nCol + nDir) {
      del = folderRepeater.itemAt(index - nCol)
    } else {
      del = trackRepeater.itemAt(index - nCol - nDir)
    }
    if (!del) {
      return null
    }
    const p = del.mapToItem(null, del.width / 2, del.height / 2)
    return {
      x: Math.round(p.x),
      y: Math.round(p.y)
    }
  }

  function outputSinks() {
    const out = []
    const nodes = Audio.nodes
    for (let i = 0; i < nodes.length; i++) {
      if (Audio.mediaClass(nodes[i]) === "Audio/Sink") {
        out.push(nodes[i])
      }
    }
    return out
  }

  function routeTargetName() {
    const stream = Mpd.streamNode
    if (!stream) {
      return ""
    }
    const props = stream.properties ? stream.properties : {}
    const direct = props["target.object"] !== undefined ? props["target.object"] : props["node.target"]
    if (direct !== undefined && direct !== null && String(direct) !== "") {
      return String(direct)
    }
    return Audio.streamTargetName(stream)
  }

  function targetLabel(node) {
    return node ? Aliases.displayName(node) : "Default"
  }

  function routeRows() {
    const rows = [
      {
        node: null,
        separator: false
      }
    ]
    const sinks = outputSinks()
    if (sinks.length > 0) {
      rows.push({
        node: null,
        separator: true
      })
    }
    for (let i = 0; i < sinks.length; i++) {
      rows.push({
        node: sinks[i],
        separator: false
      })
    }
    return rows
  }

  function openRoute(anchor) {
    if (routePopup.opened) {
      closeRoute()
      return
    }
    if (Date.now() - root.routeDismissedAt < 250) {
      return
    }
    root.routeDismissedAt = 0
    const offset = Math.round(4 * Theme.scale)
    const reference = routePopup.parent
    const anchorX = anchor.width - routePopup.width
    const anchorY = -routePopup.height - offset
    const point = reference ? anchor.mapToItem(reference, anchorX, anchorY) : anchor.mapToItem(null, anchorX, anchorY)
    routePopup.x = point.x
    routePopup.y = point.y
    routePopup.open()
  }

  function closeRoute() {
    root.routeDismissedAt = routePopup.opened ? Date.now() : 0
    routePopup.close()
  }

  function setRoute(node) {
    const stream = Mpd.streamNode
    if (!stream) {
      return
    }
    if (node) {
      Quickshell.execDetached(["pw-metadata", "-n", "default", String(stream.id), "target.object", node.name, "Spa:String"])
    } else {
      Quickshell.execDetached(["pw-metadata", "-n", "default", "-d", String(stream.id), "target.object"])
    }
    Audio.setStreamTarget(stream, node ? node.name : "")
    root.closeRoute()
  }

  function testRouteState() {
    const target = root.routeTargetName()
    const rows = [
      {
        name: "",
        label: "Default",
        current: target === ""
      }
    ]
    const sinks = root.outputSinks()
    for (let i = 0; i < sinks.length; i++) {
      rows.push({
        name: sinks[i].name,
        label: Aliases.displayName(sinks[i]),
        current: target === sinks[i].name
      })
    }
    return {
      open: root.open,
      popup: routePopup.opened,
      stream: Mpd.streamNode ? String(Mpd.streamNode.id) : "",
      target: target,
      rows: rows
    }
  }

  function testRouteOpen() {
    root.routeDismissedAt = 0
    root.openRoute(deviceBtn)
    return routePopup.opened
  }

  function testRouteTo(name) {
    if (name === "") {
      root.setRoute(null)
      return true
    }
    const sinks = root.outputSinks()
    for (let i = 0; i < sinks.length; i++) {
      if (sinks[i].name === name || Aliases.displayName(sinks[i]) === name) {
        root.setRoute(sinks[i])
        return true
      }
    }
    return false
  }

  property real routeDismissedAt: 0

  onOpened: {
    Mpd.refresh()
    Mpd.seedLibrary()
    Mpd.updateDb()
    Audio.refreshStreamTargets()
  }

  onScrolled: root.closeRoute()

  Component.onCompleted: root.syncQueueModel()

  function testSwipe(index, offset, release) {
    const del = queueList.itemAtIndex(index)
    if (!del) {
      return null
    }
    const row = del.rowCard
    if (!row.gestureActive) {
      row.gesturePress(0)
    }
    row.gestureMove(offset)
    if (release) {
      row.gestureRelease()
    }
    return {
      swipeX: Math.round(row.swipeX),
      active: row.gestureActive,
      revealed: row.revealed
    }
  }

  function testSwipeRelease() {
    const del = queueList.itemAtIndex(0)
    if (!del) {
      return null
    }
    const row = del.rowCard
    const wasActive = row.gestureActive
    row.gestureRelease()
    return {
      wasActive: wasActive,
      revealed: row.revealed,
      swipeX: Math.round(row.swipeX)
    }
  }

  function resetReveals() {
    for (let i = 0; i < queueModel.count; i++) {
      const del = queueList.itemAtIndex(i)
      if (del) {
        del.rowCard.gestureActive = false
        del.rowCard.wasGesture = false
        del.rowCard.revealed = false
        del.rowCard.swipeX = 0
      }
    }
  }

  Connections {
    target: root

    function onOpenChanged() {
      if (!root.open) {
        root.resetReveals()
      }
    }
  }

  Connections {
    target: Mpd

    function onQueueChanged() {
      root.syncQueueModel()
    }
  }

  ListModel {
    id: queueModel
  }

  Timer {
    id: seekCommitTimer

    interval: 200
    onTriggered: root.commitSeek()
  }

  Timer {
    id: searchTimer

    interval: 250
    onTriggered: root.runSearch()
  }

  NumberAnimation {
    id: navAnim

    target: foldersColumn
    property: "x"
    duration: 200
    easing.type: Easing.OutCubic
  }

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Space) {
      Mpd.toggle()
      event.accepted = true
    } else if (event.key === Qt.Key_Left) {
      Mpd.seek(Mpd.elapsed - 5)
      event.accepted = true
    } else if (event.key === Qt.Key_Right) {
      Mpd.seek(Mpd.elapsed + 5)
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      Mpd.setVolume(Mpd.displayVolume + 2)
      event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      Mpd.setVolume(Mpd.displayVolume - 2)
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      Panels.closePanel("music")
      event.accepted = true
    }
  }

  Item {
    id: coverHeader

    width: parent.width
    height: coverArt.height

    Rectangle {
      id: coverArt

      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: s(92)
      height: width
      radius: s(10)
      color: Theme.base
      antialiasing: true
      border.width: hairline()
      border.color: Theme.surfaceHigher
      clip: true

      Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: coverMask
          maskSpreadAtMin: 1.0
          maskThresholdMin: 0.5
        }

        Rectangle {
          anchors.fill: parent
          visible: Mpd.coverPath.length === 0
          gradient: Gradient {
            GradientStop {
              position: 0.0
              color: Theme.red
            }
            GradientStop {
              position: 1.0
              color: Theme.mauve
            }
          }
        }

        Image {
          anchors.fill: parent
          visible: Mpd.coverPath.length > 0
          source: Mpd.coverPath.length > 0 ? ("file://" + Mpd.coverPath) : ""
          fillMode: Image.PreserveAspectCrop
          smooth: true
          mipmap: true
          onStatusChanged: if (status === Image.Error) {
            Mpd.coverPath = ""
          }
          sourceSize.width: coverArt.width * 2
          sourceSize.height: coverArt.width * 2
        }
      }

      Rectangle {
        id: coverMask

        anchors.fill: parent
        visible: false
        radius: coverArt.radius
        color: "white"
        antialiasing: true
        layer.enabled: true
      }
    }

    Column {
      id: textColumn

      anchors.left: coverArt.right
      anchors.leftMargin: s(15)
      anchors.verticalCenter: parent.verticalCenter
      spacing: s(5)
      width: parent.width - coverArt.width - s(15)

      Item {
        width: parent.width - favPinWrap.width - s(10)
        height: folderRow.implicitHeight

        Row {
          id: folderRow

          spacing: s(5)

          Icon {
            id: folderIcon

            anchors.verticalCenter: parent.verticalCenter
            name: "folder"
            font.pixelSize: s(11)
            lineHeight: s(11)
            lineHeightMode: Text.FixedHeight
            color: Theme.mauve
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: folderRow.parent.width - folderIcon.width - folderRow.spacing
            text: Mpd.song ? root.parentFolderLabel() : "—"
            color: Theme.subtext
            font.family: "monospace"
            font.pixelSize: s(9)
            lineHeight: s(11)
            lineHeightMode: Text.FixedHeight
            elide: Text.ElideRight
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Mpd.song ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (!Mpd.song) {
              return
            }
            root.switchTab(0)
            root.goTo(Mpd.parentDir(Mpd.song.file))
          }
        }
      }

      Text {
        id: titleText

        width: parent.width
        height: s(17)
        verticalAlignment: Text.AlignVCenter
        text: Mpd.song ? Mpd.song.title : "Nothing playing"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: s(16)
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        id: artistText

        width: parent.width
        height: s(12)
        verticalAlignment: Text.AlignVCenter
        text: Mpd.song ? ((Mpd.song.artist.length > 0 ? Mpd.song.artist : "Unknown artist") + (Mpd.song.album.length > 0 ? " · " + Mpd.song.album : "")) : ""
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: s(10)
        font.weight: Font.Medium
        elide: Text.ElideRight
        visible: text.length > 0
      }

      Text {
        id: audioInfoText

        width: parent.width
        height: s(10)
        verticalAlignment: Text.AlignVCenter
        text: {
          if (!Mpd.song) {
            return ""
          }
          const parts = []
          if (Mpd.bitrate > 0) {
            parts.push(Mpd.bitrate + " kbps")
          }
          const af = Mpd.audioFormat
          if (af && af.length > 0) {
            const segs = af.split(":")
            if (segs.length >= 3) {
              const sr = parseInt(segs[0])
              if (!isNaN(sr) && sr > 0) {
                parts.push((sr / 1000).toFixed(1).replace(/\.0$/, "") + " kHz")
              }
              if (segs[1] && segs[1] !== "f") {
                parts.push(segs[1] + "-bit")
              }
              const ch = parseInt(segs[2])
              if (!isNaN(ch) && ch > 0 && ch !== 2) {
                parts.push(ch === 1 ? "mono" : ch + " ch")
              }
            } else {
              parts.push(af)
            }
          }
          return parts.join(" · ")
        }
        color: Theme.subtext
        font.family: "monospace"
        font.pixelSize: s(9)
        elide: Text.ElideRight
        visible: text.length > 0
      }
    }

    Item {
      id: favPinWrap

      anchors.top: parent.top
      anchors.right: parent.right
      width: s(60)
      height: s(26)

      Rectangle {
        id: favButton

        width: s(26)
        height: s(26)
        radius: s(13)
        anchors.left: parent.left
        color: favHover.containsMouse ? Theme.surfaceHigher : Theme.base

        Text {
          anchors.centerIn: parent
          text: Icons.get(Mpd.song && Mpd.isFavorite(Mpd.song.file) ? "heart-filled" : "heart")
          font.family: Theme.iconFamily
          font.pixelSize: s(13)
          color: Mpd.song && Mpd.isFavorite(Mpd.song.file) ? Theme.red : Theme.text
        }

        MouseArea {
          id: favHover

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!Mpd.song) {
              return
            }
            Mpd.setFavorite(Mpd.song.file, !Mpd.isFavorite(Mpd.song.file))
          }
        }
      }

      Rectangle {
        id: pinButton

        width: s(26)
        height: s(26)
        radius: s(13)
        anchors.right: parent.right
        color: pinHover.containsMouse ? Theme.surfaceHigher : Theme.base

        Text {
          anchors.centerIn: parent
          text: Icons.get(Mpd.song && Mpd.isPinned(Mpd.song.file) ? "pin-filled" : "pin")
          font.family: Theme.iconFamily
          font.pixelSize: s(13)
          color: Mpd.song && Mpd.isPinned(Mpd.song.file) ? Theme.mauve : Theme.text
        }

        MouseArea {
          id: pinHover

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!Mpd.song) {
              return
            }
            Mpd.setPinned(Mpd.song.file, !Mpd.isPinned(Mpd.song.file))
          }
        }
      }
    }
  }

  function parentFolderLabel() {
    if (!Mpd.song) {
      return "—"
    }
    const d = Mpd.parentDir(Mpd.song.file)
    const parts = d.split("/")
    return parts.length > 1 ? parts.slice(-2).join(" / ") : (parts[0] || "Music")
  }

  Item {
    id: seekRow

    width: parent.width
    height: s(10) + seekTrack.height + s(4) + elapsedText.implicitHeight
    implicitHeight: visible ? height : 0
    visible: Mpd.connected && Mpd.song !== null

    Text {
      id: elapsedText

      anchors.left: parent.left
      anchors.top: seekTrack.bottom
      anchors.topMargin: s(4)
      text: root.fmtTime(root.seeking ? root.seekPreview * Mpd.duration : Mpd.elapsed)
      color: Theme.subtext
      font.family: "monospace"
      font.pixelSize: s(10)
    }

    Text {
      anchors.right: parent.right
      anchors.top: seekTrack.bottom
      anchors.topMargin: s(4)
      text: root.fmtTime(Mpd.duration)
      color: Theme.subtext
      font.family: "monospace"
      font.pixelSize: s(10)
    }

    Rectangle {
      id: seekTrack

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: s(10)
      height: s(5)
      radius: height / 2
      color: Theme.base

      Rectangle {
        width: Math.round((seekTrack.width - seekKnob.width) * (root.seeking ? root.seekPreview : root.seekFraction) + seekKnob.width / 2)
        height: parent.height
        radius: parent.radius
        color: Theme.mauve

        Behavior on width {
          enabled: !root.seeking
          NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
          }
        }
      }

      Rectangle {
        id: seekKnob

        x: Math.round((seekTrack.width - width) * (root.seeking ? root.seekPreview : root.seekFraction))
        y: Math.round((seekTrack.height - height) / 2)
        width: s(11)
        height: s(11)
        radius: width / 2
        color: Theme.text

        Behavior on x {
          enabled: !root.seeking
          NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          root.previewSeek(mouse.x / seekTrack.width)
          root.commitSeek()
        }
        onPositionChanged: mouse => {
          if (pressed) {
            root.previewSeek(mouse.x / seekTrack.width)
          }
        }
        onPressed: mouse => {
          root.previewSeek(mouse.x / seekTrack.width)
        }
        onReleased: root.commitSeek()
      }
    }
  }

  Item {
    id: transportRow

    width: parent.width
    height: s(45)
    implicitHeight: visible ? height : 0
    visible: Mpd.connected

    Rectangle {
      width: s(35)
      height: s(35)
      radius: s(17.5)
      x: 0
      anchors.verticalCenter: parent.verticalCenter
      color: Mpd.weightedRandom ? Theme.mauve : (shuffleHover.containsMouse ? Theme.surface : "transparent")

      Text {
        anchors.centerIn: parent
        text: Icons.get("arrows-shuffle")
        font.family: Theme.iconFamily
        font.pixelSize: s(17)
        color: Mpd.weightedRandom ? Theme.onAccent : Theme.text
      }

      MouseArea {
        id: shuffleHover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Mpd.setRandomWeighted(!Mpd.weightedRandom)
      }
    }

    Rectangle {
      width: s(35)
      height: s(35)
      radius: s(17.5)
      x: parent.width * 3 / 10 - width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: prevHover.containsMouse ? Theme.surfaceHigher : Theme.base

      Text {
        anchors.centerIn: parent
        text: Icons.get("player-track-prev")
        font.family: Theme.iconFamily
        font.pixelSize: s(17)
        color: Theme.text
      }

      MouseArea {
        id: prevHover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Mpd.prev()
      }
    }

    Rectangle {
      width: s(44)
      height: s(44)
      radius: s(22)
      x: parent.width / 2 - width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: playHover.containsMouse ? Qt.lighter(Theme.mauve, 1.15) : Theme.mauve

      Text {
        anchors.centerIn: parent
        text: root.playing ? Icons.get("player-pause") : Icons.get("player-play")
        font.family: Theme.iconFamily
        font.pixelSize: s(17)
        color: Theme.onAccent
      }

      MouseArea {
        id: playHover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Mpd.toggle()
      }
    }

    Rectangle {
      width: s(35)
      height: s(35)
      radius: s(17.5)
      x: parent.width * 7 / 10 - width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: nextHover.containsMouse ? Theme.surfaceHigher : Theme.base

      Text {
        anchors.centerIn: parent
        text: Icons.get("player-track-next")
        font.family: Theme.iconFamily
        font.pixelSize: s(17)
        color: Theme.text
      }

      MouseArea {
        id: nextHover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Mpd.next()
      }
    }

    Rectangle {
      width: s(35)
      height: s(35)
      radius: s(17.5)
      x: parent.width - width
      anchors.verticalCenter: parent.verticalCenter
      color: Mpd.repeat ? Theme.mauve : (repeatHover.containsMouse ? Theme.surface : "transparent")

      Text {
        anchors.centerIn: parent
        text: Mpd.single ? Icons.get("repeat-once") : Icons.get("repeat")
        font.family: Theme.iconFamily
        font.pixelSize: s(17)
        color: Mpd.repeat ? Theme.onAccent : Theme.text
      }

      MouseArea {
        id: repeatHover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Mpd.setRepeatCycle()
      }
    }
  }

  Item {
    id: volumeRow

    width: parent.width
    height: s(34)
    implicitHeight: visible ? height : 0
    visible: Mpd.connected

    Row {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      spacing: s(7)

      Item {
        id: volumeItem
        property int prevVol: 50

        width: parent.width
        height: s(32)
        opacity: Mpd.streamStable ? 1 : 0.45

        Rectangle {
          id: volIcon

          width: s(20)
          height: s(20)
          radius: width / 2
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          color: volIconHover.containsMouse ? Theme.surfaceHigher : "transparent"

          Text {
            anchors.centerIn: parent
            text: Mpd.displayVolume === 0 || !Mpd.streamStable ? Icons.get("volume-off") : Icons.get("volume")
            font.family: Theme.iconFamily
            font.pixelSize: s(14)
            color: Theme.text
          }

          MouseArea {
            id: volIconHover

            anchors.fill: parent
            enabled: Mpd.streamStable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (Mpd.volume > 0) {
                volumeItem.prevVol = Mpd.volume
                Mpd.setVolume(0)
              } else {
                Mpd.setVolume(volumeItem.prevVol > 0 ? volumeItem.prevVol : 50)
              }
            }
          }
        }

        Slider {
          id: volSlider

          anchors.left: volIcon.right
          anchors.leftMargin: s(6)
          anchors.right: volValueWrap.left
          anchors.rightMargin: s(6)
          anchors.verticalCenter: parent.verticalCenter
          enabled: Mpd.streamStable
          wave: false
          node: Mpd.streamNode
          value: Mpd.displayVolume / 100
          fillColor: Theme.mauve
          trackColor: Theme.base
          onMoved: v => Mpd.setVolume(v * 100)
          onWheeled: delta => root.wheelVolume(delta)
        }

        Item {
          id: volValueWrap

          width: volEditor.width + s(8)
          height: s(20)
          anchors.right: deviceBtn.left
          anchors.rightMargin: s(4)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: volValueHover.containsMouse || volEditor.editing ? Theme.surfaceHigher : "transparent"
          }

          MouseArea {
            id: volValueHover

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: volEditor.editing ? Qt.IBeamCursor : Qt.PointingHandCursor
          }

          EditablePercent {
            id: volEditor

            anchors.centerIn: parent
            percent: Mpd.displayVolume
            maximum: 100
            textColor: Theme.text
            onEdited: value => Mpd.setVolume(value)
            onWheeled: delta => root.wheelVolume(delta)
            onEditingChanged: {
              if (editing) {
                root.activeEditor = volEditor
              } else if (root.activeEditor === volEditor) {
                root.activeEditor = null
              }
            }
          }
        }

        Rectangle {
          id: deviceBtn

          width: s(20)
          height: s(20)
          radius: width / 2
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          color: routeHover.containsMouse || routePopup.opened ? Theme.surfaceHigher : "transparent"
          opacity: Mpd.streamStable ? 1 : 0.45

          Text {
            anchors.centerIn: parent
            text: Icons.get("devices")
            font.family: Theme.iconFamily
            font.pixelSize: s(12)
            color: root.routeTargetName() !== "" ? Theme.mauve : Theme.text
          }

          MouseArea {
            id: routeHover

            anchors.fill: parent
            enabled: Mpd.streamStable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openRoute(deviceBtn)
          }
        }
      }
    }
  }

  Rectangle {
    id: hairlineRect

    width: parent.width
    height: hairline()
    implicitHeight: height
    color: Theme.surfaceHigher
  }

  Row {
    id: tabsRow

    width: parent.width
    height: s(30)
    spacing: s(8)

    Rectangle {
      id: tabBar

      readonly property real tabWidth: (width - s(4) * 2) / 2

      width: s(118)
      height: s(30)
      implicitHeight: height
      radius: s(8)
      color: Theme.base
      clip: true

      Rectangle {
        id: tabIndicator

        x: s(2) + root.currentTab * (tabBar.tabWidth + s(4))
        y: s(2)
        width: tabBar.tabWidth
        height: parent.height - s(4)
        radius: s(6)
        color: Theme.surface

        Behavior on x {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }
      }

      Row {
        anchors.fill: parent
        anchors.margins: s(2)
        spacing: s(4)

        Repeater {
          model: ["Folders", "Queue"]

          Rectangle {
            width: (parent.width - s(4)) / 2
            height: parent.height
            radius: s(6)
            color: tabHover.containsMouse && root.currentTab !== index ? Theme.surface : "transparent"

            Text {
              anchors.centerIn: parent
              text: modelData
              color: root.currentTab === index ? Theme.text : Theme.subtext
              font.family: Theme.fontFamily
              font.pixelSize: s(10)
              font.bold: true
            }

            MouseArea {
              id: tabHover

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.switchTab(index)
            }
          }
        }
      }
    }

    Rectangle {
      id: searchBox

      width: parent.width - tabBar.width - s(8)
      height: s(30)
      radius: s(8)
      color: Theme.base
      border.width: searchInput.activeFocus ? 1 : 0
      border.color: Theme.primary

      Text {
        anchors.left: parent.left
        anchors.leftMargin: s(10)
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.get("search")
        font.family: Theme.iconFamily
        font.pixelSize: s(12)
        color: searchInput.activeFocus ? Theme.primary : Theme.subtext
      }

      TextInput {
        id: searchInput

        anchors.left: parent.left
        anchors.leftMargin: s(26)
        anchors.right: parent.right
        anchors.rightMargin: s(8)
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: s(10)
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        text: root.searchText
        onTextChanged: root.searchText = text
        Keys.onEscapePressed: {
          text = ""
          focus = false
        }

        Text {
          anchors.fill: parent
          visible: searchInput.text === ""
          text: "Search title or artist…"
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: s(10)
          verticalAlignment: TextInput.AlignVCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: searchInput.forceActiveFocus()
        z: -1
      }
    }
  }

  Item {
    id: contentArea
    width: parent.width
    height: s(253)
    implicitHeight: height
    clip: true

    Item {
      id: foldersPage

      width: parent.width
      height: parent.height
      x: -root.currentTab * width

      Behavior on x {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutCubic
        }
      }

      Flickable {
        id: foldersFlick

        anchors.fill: parent
        contentHeight: foldersColumn.implicitHeight
        clip: true

        Column {
          id: foldersColumn

          width: parent.width
          spacing: s(4)

          Row {
            id: listHead

            width: parent.width
            height: s(32)
            spacing: s(6)

            Rectangle {
              id: backButton

              width: s(29)
              height: s(29)
              radius: s(6)
              anchors.verticalCenter: parent.verticalCenter
              visible: root.browsePath.length > 0
              color: backHover.containsMouse ? Theme.surface : "transparent"

              Text {
                anchors.centerIn: parent
                text: Icons.get("chevron-left")
                font.family: Theme.iconFamily
                font.pixelSize: s(14)
                color: Theme.text
              }

              MouseArea {
                id: backHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goTo(root.backPath())
              }
            }

            Item {
              id: crumbWrap

              width: parent.width - playBtn.width - s(6) - (backButton.visible ? backButton.width + s(6) : 0)
              height: parent.height
              clip: true

              Row {
                id: crumbRow

                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(0, crumbWrap.width - crumbRow.width)
                spacing: s(2)

                Repeater {
                  model: root.breadcrumb

                  delegate: Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label + (index < root.breadcrumb.length - 1 ? " / " : "")
                    color: index === root.breadcrumb.length - 1 ? Theme.text : Theme.subtext
                    font.family: "monospace"
                    font.pixelSize: s(9)
                    font.bold: index === root.breadcrumb.length - 1

                    MouseArea {
                      anchors.fill: parent
                      enabled: index < root.breadcrumb.length - 1
                      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: root.goTo(modelData.path)
                    }
                  }
                }
              }
            }

            Rectangle {
              id: playBtn

              width: s(96)
              height: s(29)
              radius: s(8)
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.mauve

              Row {
                anchors.centerIn: parent
                spacing: s(4)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Icons.get("player-play")
                  font.family: Theme.iconFamily
                  font.pixelSize: s(12)
                  color: Theme.onAccent
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.playLabel()
                  color: Theme.onAccent
                  font.family: Theme.fontFamily
                  font.pixelSize: s(10)
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playCurrent()
              }
            }
          }

          Text {
            id: listMeta

            width: parent.width
            height: visible ? s(16) : 0
            visible: text.length > 0
            text: root.metaText()
            leftPadding: s(12)
            verticalAlignment: Text.AlignVCenter
            color: Theme.subtext
            font.family: "monospace"
            font.pixelSize: s(9)
          }

          Repeater {
            id: collectionRepeater

            model: root.collectionRows

            delegate: MusicFolderRow {
              kind: modelData.kind
              path: modelData.path
              label: modelData.label
              activeSource: Mpd.playSource === modelData.path
              onOpen: p => root.goTo(p)
              onPlayRow: p => root.playRowPath(p)
            }
          }

          Repeater {
            id: folderRepeater

            model: root.folderRows

            delegate: MusicFolderRow {
              path: modelData.path
              label: modelData.name
              activeSource: Mpd.playSource === modelData.path
              onOpen: p => root.goTo(p)
              onPlayRow: p => Mpd.playFolder(p)
            }
          }

          Repeater {
            id: trackRepeater

            model: root.trackRows

            delegate: Rectangle {
              id: trackRow

              property var entry: modelData
              readonly property bool isCurrent: Mpd.song ? Mpd.song.file === trackRow.entry.path : false
              readonly property bool rowHovered: trackHover.containsMouse || trackFavHover.containsMouse || trackPinHover.containsMouse || trackAddHover.containsMouse

              width: foldersColumn.width
              height: s(44)
              radius: s(8)
              color: trackRow.isCurrent || trackRow.rowHovered ? Theme.surface : Theme.base

              MouseArea {
                id: trackHover

                anchors.fill: parent
                hoverEnabled: true
                onDoubleClicked: {
                  if (root.searching) {
                    root.playSearchFrom(trackRow.entry)
                  } else if (root.inCollection) {
                    if (root.browsePath === "pinned") {
                      Mpd.playPinned(trackRow.entry.path)
                    } else {
                      Mpd.playFavorites(trackRow.entry.path)
                    }
                  } else {
                    Mpd.playFolderTrack(root.browsePath === "" ? Mpd.musicDir : root.browsePath, trackRow.entry.path)
                  }
                }
              }

              Row {
                id: trackLead

                x: s(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: s(4)

                Text {
                  text: trackRow.isCurrent ? Icons.get("player-play") : String(index + 1)
                  font.family: trackRow.isCurrent ? Theme.iconFamily : "monospace"
                  font.pixelSize: s(10)
                  color: trackRow.isCurrent ? Theme.mauve : Theme.subtext
                  width: s(18)
                  horizontalAlignment: Text.AlignHCenter
                  anchors.verticalCenter: parent.verticalCenter
                }

                TrackThumb {
                  file: trackRow.entry.path
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Column {
                anchors.left: trackLead.right
                anchors.leftMargin: s(8)
                anchors.right: trackTrail.left
                anchors.rightMargin: s(8)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  text: trackRow.entry.title || trackRow.entry.name
                  color: trackRow.isCurrent ? Theme.mauve : Theme.text
                  font.family: Theme.fontFamily
                  font.pixelSize: s(10)
                  font.bold: trackRow.isCurrent
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: trackRow.entry.artist.length > 0 ? trackRow.entry.artist : "Unknown artist"
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: s(9)
                  elide: Text.ElideRight
                }
              }

              Row {
                id: trackTrail

                anchors.right: parent.right
                anchors.rightMargin: s(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: s(2)

                Rectangle {
                  width: s(24)
                  height: s(24)
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  opacity: trackRow.rowHovered ? 1 : 0
                  color: trackFavHover.containsMouse ? Theme.surfaceHigher : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: Icons.get(Mpd.isFavorite(trackRow.entry.path) ? "heart-filled" : "heart")
                    font.family: Theme.iconFamily
                    font.pixelSize: s(12)
                    color: Mpd.isFavorite(trackRow.entry.path) ? Theme.red : Theme.text
                  }

                  MouseArea {
                    id: trackFavHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mpd.setFavorite(trackRow.entry.path, !Mpd.isFavorite(trackRow.entry.path))
                  }
                }

                Rectangle {
                  width: s(24)
                  height: s(24)
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  opacity: trackRow.rowHovered ? 1 : 0
                  color: trackPinHover.containsMouse ? Theme.surfaceHigher : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: Icons.get(Mpd.isPinned(trackRow.entry.path) ? "pin-filled" : "pin")
                    font.family: Theme.iconFamily
                    font.pixelSize: s(12)
                    color: Mpd.isPinned(trackRow.entry.path) ? Theme.mauve : Theme.text
                  }

                  MouseArea {
                    id: trackPinHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mpd.setPinned(trackRow.entry.path, !Mpd.isPinned(trackRow.entry.path))
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: Mpd.fmtTime(trackRow.entry.duration)
                  font.family: "monospace"
                  font.pixelSize: s(9)
                  color: Theme.subtext
                  leftPadding: s(6)
                  rightPadding: s(2)
                }

                Rectangle {
                  width: s(24)
                  height: s(24)
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: trackAddHover.containsMouse ? Theme.surfaceHigher : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: Icons.get("plus")
                    font.family: Theme.iconFamily
                    font.pixelSize: s(13)
                    color: Theme.subtext
                  }

                  MouseArea {
                    id: trackAddHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mpd.addTrack(trackRow.entry.path)
                  }
                }
              }
            }
          }

          Text {
            width: parent.width
            height: visible ? s(24) : 0
            visible: root.collectionRows.length === 0 && root.folderRows.length === 0 && root.trackRows.length === 0 && !root.searchPending
            text: root.searching ? "No matches" : "Empty folder"
            horizontalAlignment: Text.AlignHCenter
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: s(10)
            topPadding: s(6)
          }
        }
      }
    }

    Item {
      id: queuePage

      width: parent.width
      height: parent.height
      x: (1 - root.currentTab) * width

      Behavior on x {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutCubic
        }
      }

      DragReorder {
        id: queueDragger

        listView: queueList
        model: queueModel
        keyRole: "qid"
        rowObjectName: "queueRow"
        rowHeightAt: root.queueRowHeight
        flickable: queueList
        edgeZone: s(48)
        scrollSpeed: s(12)
        onMoved: (qid, target) => Mpd.moveQueueId(qid, target)
      }

      ListView {
        id: queueList

        anchors.fill: parent
        interactive: true
        focus: false
        clip: true
        model: queueModel
        spacing: 0
        cacheBuffer: s(600)
        boundsBehavior: Flickable.StopAtBounds
        move: Transition {
          enabled: !queueDragger.suppressMove && !root.bulkQueueSync
          NumberAnimation {
            property: "y"
            duration: 220
            easing.type: Easing.OutCubic
          }
        }
        displaced: Transition {
          enabled: !queueDragger.suppressMove && !root.bulkQueueSync
          NumberAnimation {
            property: "y"
            duration: 220
            easing.type: Easing.OutCubic
          }
        }

        delegate: Item {
          id: queueDelegate

          objectName: "queueRow"

          readonly property string dragKey: qid
          readonly property alias rowCard: queueRow

          width: queueList.width
          height: root.matchesSearch(title, artist) ? (queueRow.height + s(4)) : 0
          visible: root.matchesSearch(title, artist)
          z: queueRow.dragging || queueRow.settling ? 2 : 0

          Behavior on height {
            NumberAnimation {
              duration: 150
              easing.type: Easing.OutCubic
            }
          }
          Behavior on opacity {
            NumberAnimation {
              duration: 150
              easing.type: Easing.OutCubic
            }
          }

          Rectangle {
            id: deleteReveal

            readonly property real openAmount: Math.max(0, -queueRow.swipeX)

            x: parent.width - width
            width: queueRow.height + s(12)
            height: queueRow.height
            radius: s(8)
            color: Theme.red
            visible: deleteReveal.openAmount > 0.5
            antialiasing: true

            Rectangle {
              id: deleteButton

              width: s(28)
              height: s(28)
              radius: width / 2
              color: Theme.base
              anchors.right: parent.right
              anchors.rightMargin: (parent.height - width) / 2
              anchors.verticalCenter: parent.verticalCenter
              opacity: Math.max(0, Math.min(1, (deleteReveal.openAmount - s(8)) / s(16)))
              visible: opacity > 0
              antialiasing: true

              Behavior on opacity {
                NumberAnimation {
                  duration: 150
                  easing.type: Easing.OutCubic
                }
              }

              Text {
                anchors.centerIn: parent
                text: Icons.get("trash")
                font.family: Theme.iconFamily
                font.pixelSize: s(13)
                color: Theme.red
              }

              MouseArea {
                id: removeMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Mpd.deleteQueueId(qid)
              }
            }
          }

          Rectangle {
            id: queueRow

            property bool dragging: queueDragger.dragging && queueDragger.dragKey === queueDelegate.dragKey
            property bool settling: queueDragger.settling && queueDragger.settleKey === queueDelegate.dragKey
            property real dragDelta: queueDragger.dragDelta
            property real dropShift: queueDragger.dropShift
            property real previewShift: queueDragger.previewForKey(queueDelegate.dragKey)
            property bool snapPreview: queueDragger.snapPreview
            readonly property bool rowHover: qHover.containsMouse || gripMouse.containsMouse
            property bool revealed: false
            property bool gestureActive: false
            property bool wasGesture: false
            property real revealWidth: height
            property real swipeX: revealed ? -revealWidth : 0
            property real gesturePressX: 0
            property real gestureLastX: 0
            property real gesturePrevX: 0
            property real gestureLastT: 0
            property real gesturePrevT: 0

            function gesturePress(x) {
              gestureActive = false
              wasGesture = false
              gesturePressX = gestureLastX = gesturePrevX = x
              gestureLastT = gesturePrevT = Date.now()
            }

            function gestureMove(x) {
              const now = Date.now()
              gesturePrevX = gestureLastX
              gesturePrevT = gestureLastT
              gestureLastX = x
              gestureLastT = now
              const dx = x - gesturePressX
              if (!gestureActive && Math.abs(dx) > s(6)) {
                gestureActive = true
                wasGesture = true
              }
              if (gestureActive) {
                swipeX = Math.max(-revealWidth, Math.min(0, (revealed ? -revealWidth : 0) + dx))
              }
            }

            function gestureRelease() {
              if (!gestureActive) {
                return
              }
              const still = Date.now() - gestureLastT > 80
              const dt = Math.max(1, gestureLastT - gesturePrevT)
              const velocity = (gestureLastX - gesturePrevX) / dt
              const open = !still && velocity < 0
              gestureActive = false
              revealed = open
              swipeX = open ? -revealWidth : 0
            }

            Behavior on swipeX {
              enabled: !queueRow.gestureActive
              NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
              }
            }

            width: parent.width
            height: s(44)
            radius: s(8)
            color: (Mpd.song && Mpd.song.id === qid) || rowHover ? Theme.surface : Theme.base
            opacity: queueRow.dragging || queueRow.settling ? 0.5 : 1
            layer.enabled: queueRow.dragging || queueRow.settling
            antialiasing: true
            clip: true

            transform: [
              Translate {
                y: queueRow.settling ? queueRow.dropShift : (queueRow.dragging ? queueRow.dragDelta : 0)
              },
              Translate {
                y: queueRow.dragging ? 0 : queueRow.previewShift

                Behavior on y {
                  enabled: !queueRow.snapPreview
                  NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                  }
                }
              },
              Translate {
                x: queueRow.swipeX
              }
            ]

            MouseArea {
              id: qHover

              anchors.fill: parent
              hoverEnabled: true
              preventStealing: true
              onPressed: mouse => queueRow.gesturePress(qHover.mapToItem(null, mouse.x, mouse.y).x)
              onPositionChanged: mouse => {
                if (pressed) {
                  queueRow.gestureMove(qHover.mapToItem(null, mouse.x, mouse.y).x)
                }
              }
              onReleased: queueRow.gestureRelease()
              onClicked: {
                if (queueRow.wasGesture || queueRow.revealed) {
                  return
                }
                if (Mpd.song && pos < Mpd.song.pos) {
                  return
                }
                Mpd.playQueueId(qid)
              }
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: s(8)
              anchors.rightMargin: s(3)
              spacing: s(8)

              Row {
                id: numGroup

                spacing: s(4)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: Mpd.song && Mpd.song.id === qid ? Icons.get("player-play") : String(pos + 1)
                  font.family: Mpd.song && Mpd.song.id === qid ? Theme.iconFamily : "monospace"
                  font.pixelSize: s(10)
                  color: Mpd.song && Mpd.song.id === qid ? Theme.mauve : Theme.subtext
                  width: s(18)
                  horizontalAlignment: Text.AlignHCenter
                  anchors.verticalCenter: parent.verticalCenter
                }

                TrackThumb {
                  file: model.file
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - numGroup.width - trailing.width - s(19)

                Text {
                  width: parent.width
                  text: title
                  color: Mpd.song && Mpd.song.id === qid ? Theme.mauve : Theme.text
                  font.family: Theme.fontFamily
                  font.pixelSize: s(10)
                  font.bold: Mpd.song && Mpd.song.id === qid
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: artist.length > 0 ? artist : "Unknown artist"
                  color: Theme.subtext
                  font.family: Theme.fontFamily
                  font.pixelSize: s(9)
                  elide: Text.ElideRight
                }
              }

              Item {
                id: trailing

                width: timeText.width + s(4) + grip.width
                height: s(24)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  id: timeText

                  anchors.right: grip.left
                  anchors.rightMargin: s(4)
                  anchors.verticalCenter: parent.verticalCenter
                  text: Mpd.fmtTime(duration)
                  font.family: "monospace"
                  font.pixelSize: s(9)
                  color: Theme.subtext
                }

                Rectangle {
                  id: grip

                  objectName: "queueGrip"

                  width: s(24)
                  height: s(24)
                  radius: width / 2
                  color: gripMouse.containsMouse ? Theme.surfaceHigher : "transparent"
                  antialiasing: true
                  anchors.right: parent.right
                  anchors.rightMargin: 0
                  anchors.verticalCenter: parent.verticalCenter

                  Icon {
                    anchors.centerIn: parent
                    name: "grip-vertical"
                    color: queueRow.dragging ? Theme.primary : Theme.subtext
                    font.pixelSize: s(13)
                  }

                  MouseArea {
                    id: gripMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.DragMoveCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    preventStealing: true
                    onPressed: mouse => {
                      if (mouse.button === Qt.RightButton) {
                        queueDragger.cancel()
                        return
                      }
                      queueDragger.begin(qid, gripMouse.mapToItem(null, mouse.x, mouse.y).y)
                    }
                    onPositionChanged: mouse => queueDragger.update(gripMouse.mapToItem(null, mouse.x, mouse.y).y)
                    onReleased: mouse => {
                      if (mouse.button === Qt.LeftButton) {
                        queueDragger.end()
                      }
                    }
                    onCanceled: queueDragger.cancel()
                  }
                }
              }
            }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        visible: queueDragger.dragging
        enabled: queueDragger.dragging
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.DragMoveCursor
        z: 10
        onPressed: mouse => {
          if (mouse.button === Qt.RightButton) {
            queueDragger.cancel()
          }
        }
      }

      Text {
        visible: Mpd.queue.length === 0
        text: "Queue is empty"
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: s(10)
        anchors.top: parent.top
        anchors.topMargin: s(4)
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }
  }

  Text {
    visible: !Mpd.connected
    width: parent.width
    height: visible ? s(20) : 0
    text: "Nothing playing"
    horizontalAlignment: Text.AlignHCenter
    color: Theme.subtext
    font.family: Theme.fontFamily
    font.pixelSize: s(12)
  }

  Popup {
    id: routePopup

    popupType: Popup.Item
    modal: false
    padding: Math.round(3 * Theme.scale)
    width: Math.round(176 * Theme.scale)
    height: routeColumn.implicitHeight + Math.round(6 * Theme.scale)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: {
      if (root.routeDismissedAt === 0) {
        root.routeDismissedAt = Date.now()
      }
    }

    background: Rectangle {
      color: Theme.surface
      radius: Theme.rowRadius
      border.width: 1
      border.color: Theme.surfaceHigher
      antialiasing: true
    }

    contentItem: Column {
      id: routeColumn

      spacing: Math.round(1 * Theme.scale)

      Repeater {
        model: root.routeRows()

        delegate: Item {
          id: routeOption

          required property var modelData

          readonly property bool separator: modelData.separator === true
          readonly property var optionNode: modelData.node

          width: routeColumn.width
          height: separator ? Math.round(1 * Theme.scale) : Math.round(22 * Theme.scale)

          Rectangle {
            anchors.fill: parent
            visible: !routeOption.separator
            radius: Math.round(6 * Theme.scale)
            color: optionMouse.containsMouse ? Theme.surfaceHigher : "transparent"
            antialiasing: true
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(1 * Theme.scale)
            visible: routeOption.separator
            color: Theme.surfaceHigher
          }

          Item {
            id: optionCheck

            anchors.left: parent.left
            anchors.leftMargin: Math.round(6 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(16 * Theme.scale)
            height: width

            Icon {
              anchors.centerIn: parent
              visible: !routeOption.separator && (routeOption.optionNode ? root.routeTargetName() === routeOption.optionNode.name : root.routeTargetName() === "")
              name: "check"
              color: Theme.primary
              font.pixelSize: Math.round(9 * Theme.scale)
            }
          }

          Text {
            anchors.left: optionCheck.right
            anchors.leftMargin: Math.round(4 * Theme.scale)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(8 * Theme.scale)
            anchors.verticalCenter: parent.verticalCenter
            visible: !routeOption.separator
            text: root.targetLabel(routeOption.optionNode)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(9 * Theme.scale)
            elide: Text.ElideRight
          }

          MouseArea {
            id: optionMouse

            anchors.fill: parent
            enabled: !routeOption.separator
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setRoute(routeOption.optionNode)
          }
        }
      }
    }
  }
}
