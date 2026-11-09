pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "."

Singleton {
  id: root

  readonly property alias server: instance

  readonly property alias active: instance.trackedNotifications

  property bool dnd: false
  property bool idle: Idle.active
  property bool locked: false
  property var records: []
  property string lastError: ""
  property int arrivals: 0

  property string bannerPhase: "hidden"
  property var bannerSelected: null
  property real bannerRemaining: 0
  property real bannerCompactRemaining: 0
  property real bannerRetreatRemaining: 0
  property real bannerElapsed: 0
  property bool bannerHover: false
  property bool bannerManual: false
  property bool bannerAcknowledged: false
  property bool bannerDeferred: false
  property bool bannerReplayPending: false
  property bool bannerHold: false

  readonly property int bannerCap: 15000
  readonly property int bannerSession: 5000
  readonly property int bannerCompactDwell: 250
  readonly property int bannerStepMs: 50
  readonly property int bannerRetreatMs: 360
  readonly property int bannerRowLimit: 3
  readonly property var sidePanels: ["volume", "battery", "network", "bluetooth"]

  readonly property bool bannerVisible: bannerPhase !== "hidden"
  readonly property bool bannerCritical: bannerCriticalActive()
  readonly property int bannerCount: bannerGroup.length
  readonly property var bannerRows: bannerRowsList()
  readonly property int bannerMore: Math.max(0, bannerGroup.length - 1 - bannerRows.length)
  readonly property real bannerCriticalRemaining: bannerCritical ? Math.max(0, bannerCap - bannerElapsed) : -1

  readonly property var bannerGroup: bannerGroupList()

  readonly property string imageTmpDir: "/tmp/quickshell-notif-img"
  readonly property string soundDir: "/run/current-system/sw/share/sounds/freedesktop/stereo/"
  property int imageSeq: 0

  function bannerGroupList() {
    const out = []
    if (root.locked) {
      return out
    }
    for (let i = root.records.length - 1; i >= 0; i--) {
      const record = root.records[i]
      if (!root.shouldToast(record.n)) {
        continue
      }
      out.push(record)
    }
    return out
  }

  function bannerRowsList() {
    const group = root.bannerGroup
    const out = []
    for (let i = 0; i < group.length && out.length < root.bannerRowLimit; i++) {
      if (group[i] !== root.bannerSelected) {
        out.push(group[i])
      }
    }
    return out
  }

  function bannerCriticalActive() {
    const group = root.bannerGroup
    for (let i = 0; i < group.length; i++) {
      if (group[i].n.urgency === NotificationUrgency.Critical) {
        return true
      }
    }
    return false
  }

  function selectedIndex() {
    const group = root.bannerGroup
    for (let i = 0; i < group.length; i++) {
      if (group[i] === root.bannerSelected) {
        return i
      }
    }
    return -1
  }

  function findRecord(n) {
    for (let i = 0; i < root.records.length; i++) {
      if (root.records[i].n === n) {
        return root.records[i]
      }
    }
    return null
  }

  function timeOf(n) {
    const r = root.findRecord(n)
    return r ? r.snap.ts : Math.floor(Date.now() / 1000)
  }

  function stickyOf(n) {
    return n.urgency === NotificationUrgency.Critical || n.resident || n.expireTimeout === 0
  }

  function shouldToast(n) {
    if (root.locked) {
      return false
    }
    if (root.dnd && n.urgency !== NotificationUrgency.Critical) {
      return false
    }
    return true
  }

  function isSticky(n) {
    const r = root.findRecord(n)
    return r ? r.sticky : stickyOf(n)
  }

  function remainingFor(n) {
    const r = root.findRecord(n)
    return r ? Math.max(0, Math.ceil(r.remaining)) : -1
  }

  function hoverPaused(n) {
    const r = root.findRecord(n)
    return r ? r.hoverPause : false
  }

  function setBannerHover(hovered) {
    root.bannerHover = hovered
    const group = root.bannerGroup
    for (let i = 0; i < group.length; i++) {
      group[i].hoverPause = hovered
    }
  }

  function setBannerHold(enabled) {
    root.bannerHold = enabled
  }

  function timeoutFor(n) {
    if (n.expireTimeout > 0) {
      return n.expireTimeout
    }
    if (n.urgency === NotificationUrgency.Critical) {
      return 0
    }
    if (n.urgency === NotificationUrgency.Low) {
      return 4000
    }
    return 5000
  }

  function dismissAll() {
    const list = active
    if (!list) {
      return
    }
    const vals = Array.from(list.values)
    for (let i = 0; i < vals.length; i++) {
      vals[i].dismiss()
    }
  }

  function panelIsNotifications() {
    return Panels.panel === "notifications" && Panels.screenName === "eDP-1"
  }

  function bannerSuppressed() {
    if (Panels.panel === "" || Panels.screenName !== "eDP-1") {
      return false
    }
    return root.sidePanels.indexOf(Panels.panel) === -1
  }

  function stopBanner() {
    if (root.bannerHover) {
      root.setBannerHover(false)
    }
    root.bannerPhase = "hidden"
    root.bannerSelected = null
    root.bannerRemaining = 0
    root.bannerCompactRemaining = 0
    root.bannerRetreatRemaining = 0
    root.bannerElapsed = 0
    root.bannerManual = false
  }

  function startBanner(instant) {
    if (root.locked || root.bannerSuppressed() || root.bannerGroup.length === 0) {
      return
    }
    root.bannerAcknowledged = false
    root.bannerDeferred = false
    root.bannerReplayPending = false
    root.bannerManual = false
    root.bannerSelected = root.bannerGroup[0]
    root.bannerPhase = instant === true ? "expanded" : "compact"
    root.bannerCompactRemaining = instant === true ? 0 : root.bannerCompactDwell
    root.bannerRemaining = root.bannerSession
    root.bannerRetreatRemaining = 0
    root.bannerElapsed = 0
    if (root.bannerHover) {
      root.setBannerHover(false)
    }
  }

  function presentArrival(record) {
    if (root.locked) {
      return
    }
    if (root.bannerSuppressed()) {
      if (root.panelIsNotifications()) {
        root.bannerAcknowledged = true
        root.bannerDeferred = false
      } else {
        root.bannerAcknowledged = false
        root.bannerDeferred = true
      }
      return
    }
    if (root.bannerPhase === "hidden") {
      root.startBanner(true)
      return
    }
    root.bannerAcknowledged = false
    root.bannerDeferred = false
    root.bannerRemaining = root.bannerSession
    if (root.bannerPhase === "retreating" || root.bannerPhase === "compact") {
      root.bannerPhase = "expanded"
      root.bannerCompactRemaining = 0
      root.bannerRetreatRemaining = 0
      root.bannerElapsed = 0
    }
    if (!root.bannerManual && !root.bannerHover) {
      root.bannerSelected = record
    }
    if (root.bannerSelected === null) {
      root.bannerSelected = record
    }
  }

  function startRetreat() {
    if (root.bannerPhase === "hidden" || root.bannerPhase === "retreating") {
      return
    }
    root.bannerPhase = "retreating"
    root.bannerCompactRemaining = 0
    root.bannerRemaining = 0
    root.bannerRetreatRemaining = root.bannerRetreatMs
  }

  function finishRetreat() {
    const replay = root.bannerReplayPending
    root.stopBanner()
    root.bannerAcknowledged = false
    root.bannerDeferred = false
    root.bannerReplayPending = false
    if (replay && !root.locked && !root.bannerSuppressed() && root.bannerGroup.length > 0) {
      root.startBanner()
    }
  }

  function acknowledgeBanner() {
    root.bannerAcknowledged = true
    root.bannerDeferred = false
    root.bannerReplayPending = false
    if (root.bannerPhase !== "hidden") {
      root.stopBanner()
    }
  }

  function expandBannerNow() {
    if (root.bannerPhase !== "compact") {
      return false
    }
    root.bannerCompactRemaining = 0
    root.bannerPhase = "expanded"
    return true
  }

  function selectBanner(record) {
    if (!record || root.bannerGroup.indexOf(record) === -1) {
      return false
    }
    root.bannerSelected = record
    root.bannerManual = true
    return true
  }

  function selectBannerIndex(index) {
    const group = root.bannerGroup
    if (index < 0 || index >= group.length) {
      return false
    }
    return root.selectBanner(group[index])
  }

  function selectBannerRow(index) {
    const rows = root.bannerRows
    if (index < 0 || index >= rows.length) {
      return false
    }
    return root.selectBanner(rows[index])
  }

  function dismissBannerSelected() {
    if (root.bannerSelected === null) {
      return false
    }
    root.bannerSelected.n.dismiss()
    return true
  }

  function dismissBannerRow(index) {
    const rows = root.bannerRows
    if (index < 0 || index >= rows.length) {
      return false
    }
    rows[index].n.dismiss()
    return true
  }

  function reconcileBanner() {
    const group = root.bannerGroup
    if (group.length === 0) {
      if (root.bannerPhase !== "hidden") {
        root.startRetreat()
      }
      root.bannerDeferred = false
      root.bannerReplayPending = false
      return
    }
    if (root.bannerPhase === "hidden") {
      return
    }
    if (root.bannerSelected !== null && group.indexOf(root.bannerSelected) !== -1) {
      return
    }
    root.bannerSelected = group[0]
    root.bannerManual = false
  }

  function handlePanels() {
    if (root.bannerSuppressed()) {
      if (root.panelIsNotifications()) {
        root.bannerAcknowledged = true
        root.bannerDeferred = false
        root.bannerReplayPending = false
        if (root.bannerPhase !== "hidden") {
          root.stopBanner()
        }
        return
      }
      if (root.bannerPhase !== "hidden") {
        root.bannerAcknowledged = false
        root.bannerDeferred = true
        root.bannerReplayPending = false
        root.stopBanner()
      }
      return
    }
    if (root.bannerDeferred) {
      if (root.bannerAcknowledged || root.locked || root.bannerGroup.length === 0) {
        root.bannerDeferred = false
        root.bannerAcknowledged = false
        return
      }
      if (root.bannerPhase === "retreating") {
        root.bannerReplayPending = true
        return
      }
      if (root.bannerPhase === "hidden" && Panels.panel === "") {
        root.startBanner()
      }
      return
    }
  }

  function handlePanelClosed(screen) {
    if (screen !== "eDP-1") {
      return
    }
    root.handlePanels()
    if (!root.bannerVisible && !root.bannerDeferred) {
      root.bannerAcknowledged = false
    }
  }

  function stepBanner(delta) {
    if (root.bannerPhase === "hidden") {
      return
    }
    const paused = root.bannerHold || root.bannerHover || (root.idle && !root.locked)
    if (paused) {
      return
    }
    if (root.bannerPhase === "retreating") {
      root.bannerRetreatRemaining -= delta
      if (root.bannerRetreatRemaining <= 0) {
        root.finishRetreat()
      }
      return
    }
    root.bannerElapsed += delta
    root.bannerRemaining -= delta
    if (root.bannerPhase === "compact") {
      root.bannerCompactRemaining -= delta
      if (root.bannerCompactRemaining <= 0) {
        root.bannerCompactRemaining = 0
        root.bannerPhase = "expanded"
      }
    }
    if (root.bannerRemaining <= 0 || (root.bannerCritical && root.bannerElapsed >= root.bannerCap) || root.bannerGroup.length === 0) {
      root.startRetreat()
    }
  }

  function advanceBanner(ms) {
    let left = Math.max(0, Math.floor(ms))
    while (left > 0) {
      const delta = Math.min(root.bannerStepMs, left)
      root.stepBanner(delta)
      left -= delta
    }
  }

  function arrive(n) {
    try {
      arriveInner(n)
    } catch (e) {
      root.lastError = String(e) + " | " + (e && e.stack ? e.stack : "")
    }
  }

  function arriveInner(n) {
    const existing = root.findRecord(n)
    if (existing) {
      existing.remaining = root.timeoutFor(n)
      existing.sticky = existing.sticky || root.stickyOf(n)
      if (!n.lastGeneration && root.shouldToast(n) && !root.bannerSuppressed()) {
        root.presentArrival(existing)
      }
      return
    }
    n.tracked = true
    let staged = ""
    const img = root.localImagePath(n.image)
    if (img !== "") {
      root.imageSeq += 1
      staged = root.imageTmpDir + "/" + root.imageSeq + ".img"
      Quickshell.execDetached(["cp", "-f", img, staged])
    }
    n.closed.connect(reason => root.closed(n, reason))
    const snap = {
      ts: Math.floor(Date.now() / 1000),
      appName: n.appName,
      appIcon: n.appIcon,
      desktopEntry: n.desktopEntry,
      summary: n.summary,
      body: n.body,
      urgency: n.urgency,
      actions: n.actions.map(a => a.text),
      transient: n.transient,
      avatarKey: root.avatarKeyOf(n),
      image: String(n.image || "")
    }
    const record = {
      n: n,
      remaining: root.locked ? 0 : root.timeoutFor(n),
      sticky: root.stickyOf(n),
      hoverPause: false,
      imageTmp: staged,
      avatarTmp: "",
      snap: snap
    }
    root.records = root.records.concat([record])
    if (root.locked) {
      NotifStore.noteArrival()
      root.arrivals += 1
      return
    }
    if (!n.lastGeneration) {
      NotifStore.noteArrival()
      root.arrivals += 1
      if (root.shouldToast(n)) {
        root.playChime(n)
        root.presentArrival(record)
      }
    }
  }

  function closed(n, reason) {
    const r = root.findRecord(n)
    if (!r) {
      return
    }
    root.records = root.records.filter(x => x.n !== n)
    NotifStore.record({
      ts: r.snap.ts,
      appName: r.snap.appName,
      appIcon: r.snap.appIcon,
      desktopEntry: r.snap.desktopEntry,
      summary: r.snap.summary,
      body: r.snap.body,
      urgency: r.snap.urgency,
      actions: r.snap.actions,
      transient: r.snap.transient,
      imageTmp: r.imageTmp,
      avatarKey: r.snap.avatarKey,
      avatarTmp: r.avatarTmp || ""
    })
  }

  function localImagePath(src) {
    let p = src === undefined || src === null ? "" : String(src)
    if (p.indexOf("image://icon/") === 0) {
      p = p.substring(13)
    } else if (p.indexOf("file://") === 0) {
      p = decodeURIComponent(p.substring(7))
    }
    if (p.indexOf("/") !== 0) {
      return ""
    }
    return p
  }

  function avatarKeyOf(n) {
    if (!n || !String(n.image || "").startsWith("image://qsimage/")) {
      return ""
    }
    if (!n.appName || !n.summary) {
      return ""
    }
    return n.appName + "\u001f" + n.summary
  }

  function captureAvatar(n, item) {
    const key = root.avatarKeyOf(n)
    if (key === "") {
      return
    }
    root.imageSeq += 1
    const path = root.imageTmpDir + "/avatar-" + root.imageSeq + ".png"
    item.grabToImage(result => {
      if (!result || !result.saveToFile(path)) {
        return
      }
      const entry = root.findRecord(n)
      if (entry) {
        entry.avatarTmp = path
      } else {
        Quickshell.execDetached(["rm", "-f", path])
      }
    })
  }

  function playChime(n) {
    if (chimeProc.running) {
      return
    }
    const hints = n.hints
    const sf = hints && hints["sound-file"] ? String(hints["sound-file"]) : ""
    const sn = hints && hints["sound-name"] ? String(hints["sound-name"]) : ""
    let file = ""
    if (sf !== "") {
      file = sf.indexOf("file://") === 0 ? decodeURIComponent(sf.substring(7)) : sf
    } else if (sn !== "") {
      file = root.soundDir + sn + (sn.indexOf(".") === -1 ? ".oga" : "")
    } else {
      file = root.soundDir + (n.urgency === NotificationUrgency.Critical ? "dialog-warning.oga" : "message-new-instant.oga")
    }
    chimeProc.command = ["pw-play", file]
    chimeProc.running = true
  }

  function tick() {
    const pausedByBanner = root.bannerVisible
    const group = root.bannerGroup
    let expired = false
    const next = []
    for (let i = 0; i < root.records.length; i++) {
      const r = root.records[i]
      const inBanner = pausedByBanner && group.indexOf(r) !== -1
      if (!r.sticky && !r.hoverPause && !inBanner && !(root.idle && !root.locked)) {
        r.remaining -= tickTimer.interval
        if (r.remaining <= 0) {
          r.n.expire()
          expired = true
          continue
        }
      }
      next.push(r)
    }
    if (expired) {
      root.records = next
    }
  }

  onRecordsChanged: root.reconcileBanner()

  onDndChanged: root.reconcileBanner()

  onLockedChanged: {
    if (root.locked) {
      root.bannerAcknowledged = true
      root.bannerDeferred = false
      root.bannerReplayPending = false
      root.stopBanner()
    } else if (root.bannerPhase === "hidden") {
      root.bannerAcknowledged = false
    }
    root.reconcileBanner()
  }

  Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.imageTmpDir])

  Timer {
    id: tickTimer

    interval: 250
    running: root.records.length > 0
    repeat: true
    onTriggered: root.tick()
  }

  Timer {
    id: bannerTimer

    interval: root.bannerStepMs
    running: root.bannerVisible
    repeat: true
    onTriggered: root.stepBanner(root.bannerStepMs)
  }

  Connections {
    target: Panels

    function onPanelChanged() {
      root.handlePanels()
    }

    function onScreenNameChanged() {
      root.handlePanels()
    }

    function onCloseCleared(name, screen) {
      root.handlePanelClosed(screen)
    }
  }

  Process {
    id: chimeProc
  }

  NotificationServer {
    id: instance

    keepOnReload: true
    bodySupported: true
    actionsSupported: true
    imageSupported: true

    onNotification: notification => root.arrive(notification)
  }
}
