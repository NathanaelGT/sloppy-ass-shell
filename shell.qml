import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "services"
import "bar"
import "panels"
import "osd"
import "lock"

ShellRoot {
  id: root

  property string lastReloadError: ""
  property bool suppressReloadPopup: false

  Component.onCompleted: Quickshell.watchFiles = false

  function workToast(urgency, title, body) {
    Quickshell.execDetached(["notify-send", "-a", "opencode", "-u", urgency, title, body])
  }

  Connections {
    target: Quickshell

    function onReloadFailed(errorString) {
      root.lastReloadError = errorString
      if (root.suppressReloadPopup) {
        Quickshell.inhibitReloadPopup()
      }
    }

    function onReloadCompleted() {
      root.lastReloadError = ""
    }
  }

  IpcHandler {
    target: "shell"

    function setIdle(state: bool): void {
      Notifs.idle = state
    }

    function setLocked(state: bool): void {
      Notifs.locked = state
    }

    function lock(): void {
      LockState.requestLock()
    }

    function locked(): bool {
      return LockState.sessionLocked
    }

    function launcher(): void {
      Panels.toggle("launcher", Hypr.focusedScreenName)
    }

    function power(): void {
      Panels.toggle("power", Hypr.focusedScreenName)
    }

    function dashboard(): void {
      Panels.toggle("dashboard", Hypr.focusedScreenName)
    }

    function network(): void {
      Panels.toggle("network", Hypr.focusedScreenName)
    }

    function bluetooth(): void {
      Panels.toggle("bluetooth", Hypr.focusedScreenName)
    }

    function volumePanel(): void {
      Panels.toggle("volume", Hypr.focusedScreenName)
    }

    function battery(): void {
      Panels.toggle("battery", Hypr.focusedScreenName)
    }

    function music(): void {
      Panels.toggle("music", Hypr.focusedScreenName)
    }

    function notifications(): void {
      Panels.toggle("notifications", Hypr.focusedScreenName)
    }

    function windowSwitcher(): void {
      Panels.toggle("window-switcher", Hypr.focusedScreenName)
    }

    function close(): void {
      Panels.close()
    }

    function reload(): bool {
      if (LockState.sessionLocked) {
        return false
      }
      Quickshell.reload(false)
      return true
    }

    function volumeUp(): void {
      Audio.changeVolume(0.05)
      showVolume()
    }

    function volumeDown(): void {
      Audio.changeVolume(-0.05)
      showVolume()
    }

    function volumeMute(): void {
      Audio.toggleMute()
      showVolume()
    }

    function micMute(): void {
      Audio.toggleMicMute()
      Osd.show(Audio.micMuted ? "microphone-off" : "microphone", Audio.micMuted ? "Muted" : "Unmuted", -1)
    }

    function brightnessUp(): void {
      Brightness.change(0.05)
      showBrightness()
    }

    function brightnessDown(): void {
      Brightness.change(-0.05)
      showBrightness()
    }

    function mediaPlayPause(): void {
      if (Media.active) {
        Media.active.togglePlaying()
      }
    }

    function mediaNext(): void {
      if (Media.active) {
        Media.active.next()
      }
    }

    function mediaPrevious(): void {
      if (Media.active) {
        Media.active.previous()
      }
    }

    function screenshotRegion(): void {
      Screenshot.region()
    }

    function screenshotWindow(): void {
      Screenshot.activeWindow()
    }

    function screenshotMonitor(): void {
      Screenshot.focusedMonitor()
    }

    function screenshotAll(): void {
      Screenshot.allMonitors()
    }

    function screenshotAnnotate(): void {
      Screenshot.annotate()
    }

    function notificationsClear(): void {
      Notifs.dismissAll()
    }

    function showVolume(): void {
      const glyph = Audio.muted || Audio.volume <= 0 ? "volume-off" : Audio.volume < 0.34 ? "volume-1" : Audio.volume < 0.67 ? "volume-2" : "volume-3"
      Osd.show(glyph, Math.round(Audio.volume * 100) + "%", Audio.muted ? 0 : Audio.volume)
    }

    function showBrightness(): void {
      Osd.show(Brightness.level > 0.5 ? "sun-high" : "sun-low", Math.round(Brightness.level * 100) + "%", Brightness.level)
    }
  }

  IpcHandler {
    target: "test"

    function enabled(): bool {
      return TestDriver.active
    }

    function setActive(enabled: bool): bool {
      TestDriver.active = enabled
      return TestDriver.active
    }

    function workState(): string {
      return JSON.stringify({
        active: TestDriver.active,
        watchFiles: Quickshell.watchFiles
      })
    }

    function reloadError(): string {
      return JSON.stringify({
        error: root.lastReloadError
      })
    }

    function setWatchFiles(state: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      Quickshell.watchFiles = state
      return Quickshell.watchFiles
    }

    function reloadNow(hard: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      if (LockState.sessionLocked) {
        return false
      }
      root.lastReloadError = ""
      Quickshell.reload(hard === true)
      return true
    }

    function beginWork(): string {
      TestDriver.active = true
      root.suppressReloadPopup = true
      root.lastReloadError = ""
      root.workToast("normal", "opencode", "test mode on")
      return JSON.stringify({
        active: TestDriver.active,
        watchFiles: Quickshell.watchFiles
      })
    }

    function endWork(): string {
      root.suppressReloadPopup = false
      TestDriver.active = false
      root.workToast("low", "opencode", "testing done — all yours")
      return JSON.stringify({
        active: TestDriver.active,
        watchFiles: Quickshell.watchFiles
      })
    }

    function openVolume(screen: string): bool {
      if (!TestDriver.active) {
        return false
      }
      Panels.open("volume", screen ? screen : "eDP-1")
      return true
    }

    function queueState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testQueueState()
      state.enabled = true
      return JSON.stringify(state)
    }

    function queueDrag(from: int, to: int): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const moved = panel.testQueueDrag(from, to)
      moved.enabled = true
      moved.open = true
      return JSON.stringify(moved)
    }

    function queueDragHold(from: int, to: int): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const moved = panel.testQueueDragHold(from, to)
      moved.enabled = true
      moved.open = true
      return JSON.stringify(moved)
    }

    function queueDrop(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      panel.testQueueDrop()
      return JSON.stringify({
        enabled: true,
        open: true,
        dropped: true
      })
    }

    function queueDragEdge(edge: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      panel.testQueueDragEdge(edge)
      return JSON.stringify({
        enabled: true,
        open: true,
        edge: edge
      })
    }

    function queueDragY(y: real): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      panel.testQueueDragUpdate(y)
      return JSON.stringify({
        enabled: true,
        open: true,
        y: y
      })
    }

    function queueCancel(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      panel.testQueueCancel()
      return JSON.stringify({
        enabled: true,
        open: true,
        cancelled: true
      })
    }

    function queueRects(index: int): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rects = panel.testControlRects(index)
      if (!rects) {
        return "{\"enabled\":true,\"open\":true,\"empty\":true}"
      }
      rects.enabled = true
      rects.open = true
      return JSON.stringify(rects)
    }

    function queueSwipe(index: int, offset: int, release: bool): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testSwipe(index, offset, release)
      if (!state) {
        return "{\"enabled\":true,\"open\":true,\"empty\":true}"
      }
      state.enabled = true
      state.open = true
      return JSON.stringify(state)
    }

    function queueRelease(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testSwipeRelease()
      if (!state) {
        return "{\"enabled\":true,\"open\":true,\"empty\":true}"
      }
      state.enabled = true
      state.open = true
      return JSON.stringify(state)
    }

    function musicRouteState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testRouteState()
      state.enabled = true
      return JSON.stringify(state)
    }

    function musicRouteOpen(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      return JSON.stringify({
        enabled: true,
        open: true,
        popup: panel.testRouteOpen()
      })
    }

    function musicRoute(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testRouteTo(name)
    }

    function closePanel(): bool {
      if (!TestDriver.active) {
        return false
      }
      Panels.close()
      return true
    }

    function dashState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("dashboard")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      return panel.testDashState()
    }

    function dashPick(index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("dashboard")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testDashPick(index)
    }

    function dashPlayerOpen(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("dashboard")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testDashPlayerOpen()
    }

    function dashMonth(delta: int): string {
      if (!TestDriver.active) {
        return ""
      }
      const panel = TestDriver.panel("dashboard")
      if (!panel || !panel.open) {
        return ""
      }
      return panel.testDashMonth(delta)
    }

    function clockAltTime(enabled: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      ClockState.showAltTime = enabled
      return ClockState.showAltTime
    }

    function volumeState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const nameEditor = panel.activeNameEditor
      const percentEditor = panel.activePercentEditor
      const editor = nameEditor ? nameEditor : percentEditor
      return JSON.stringify({
        enabled: true,
        open: true,
        editing: editor !== null && editor !== undefined,
        editorKind: nameEditor ? "name" : (percentEditor ? "percent" : ""),
        displayText: editor ? (nameEditor ? editor.text : String(Math.round(editor.percent))) : "",
        draft: editor ? editor.testDraft : "",
        caret: editor ? editor.testCursorPosition : -1
      })
    }

    function deviceNames(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const names = panel.testDeviceNames()
      names.enabled = true
      names.open = true
      return JSON.stringify(names)
    }

    function editorRect(text: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rect = panel.testEditorRect(text)
      if (!rect) {
        return "{\"enabled\":true,\"open\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.open = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function priorityOrder(kind: string): string {
      if (!TestDriver.active) {
        return "[]"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "[]"
      }
      return JSON.stringify(panel.testPriorityOrder(kind))
    }

    function priorityMove(kind: string, name: string, target: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testPriorityMove(kind, name, target)
    }

    function appOrder(): string {
      if (!TestDriver.active) {
        return "[]"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "[]"
      }
      return JSON.stringify(panel.testAppOrder())
    }

    function appMove(name: string, target: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testMoveApp(name, target)
    }

    function beginName(text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      const editor = panel.testFindEditor(text)
      if (!editor) {
        return false
      }
      editor.begin()
      return true
    }

    function setDraft(text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open || !panel.activeEditor) {
        return false
      }
      panel.activeEditor.testSetText(text)
      return true
    }

    function dispatch(x: real, y: real): string {
      if (!TestDriver.active) {
        return "disabled"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "no-panel"
      }
      return panel.testDispatch(x, y)
    }

    function commit(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open || !panel.activeEditor) {
        return false
      }
      panel.activeEditor.testCommit()
      return true
    }

    function cancelEdit(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open || !panel.activeEditor) {
        return false
      }
      panel.activeEditor.testCancel()
      return true
    }

    function beginDevicePercent(kind: string, text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      const editor = panel.testFindDevicePercentEditor(kind, text)
      if (!editor) {
        return false
      }
      editor.begin()
      return true
    }

    function beginAppPercent(app: string, index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      const editor = panel.testFindAppPercentEditor(app, index)
      if (!editor) {
        return false
      }
      editor.begin()
      return true
    }

    function devicePercentRect(kind: string, text: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rect = panel.testDevicePercentRect(kind, text)
      if (!rect) {
        return "{\"enabled\":true,\"open\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.open = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function appPercentRect(app: string, index: int): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rect = panel.testAppPercentRect(app, index)
      if (!rect) {
        return "{\"enabled\":true,\"open\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.open = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function nodeName(text: string): string {
      if (!TestDriver.active) {
        return ""
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return ""
      }
      return panel.testNodeName(text)
    }

    function clearAlias(node: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testClearAlias(node)
    }

    function openPanel(name: string, screen: string): bool {
      if (!TestDriver.active) {
        return false
      }
      Panels.open(name, screen ? screen : "eDP-1")
      return true
    }

    function panelState(name: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel(name)
      if (!panel || !panel.open) {
        return JSON.stringify({
          enabled: true,
          open: false,
          screen: ""
        })
      }
      return JSON.stringify({
        enabled: true,
        open: true,
        screen: panel.screenId,
        stemEnabled: panel.stemEnabled,
        stemX: panel.stemX,
        stemProgress: panel.stemProgress,
        cardX: panel.cardX,
        cardWidth: panel.cardWidth
      })
    }

    function musicState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      return JSON.stringify({
        enabled: true,
        open: panel !== null && panel !== undefined && panel.open,
        connected: Mpd.connected,
        version: Mpd.version,
        state: Mpd.state,
        song: Mpd.song,
        elapsed: Mpd.elapsed,
        volume: Mpd.volume,
        displayVolume: Mpd.displayVolume,
        streamStable: Mpd.streamStable,
        repeat: Mpd.repeat,
        random: Mpd.random,
        single: Mpd.single,
        queueLength: Mpd.queue.length,
        queue: Mpd.queue,
        musicDir: Mpd.musicDir,
        artUrl: Mpd.artUrl,
        socketPath: Mpd.socketPath
      })
    }

    function musicSocket(path: string): bool {
      if (!TestDriver.active) {
        return false
      }
      Mpd.setSocket(path)
      return true
    }

    function musicCmd(cmd: string): string {
      if (!TestDriver.active) {
        return "inactive"
      }
      if (cmd === "toggle") {
        Mpd.toggle()
      } else if (cmd === "play") {
        if (Mpd.state !== "play") {
          Mpd.toggle()
        }
      } else if (cmd === "pause") {
        if (Mpd.state === "play") {
          Mpd.toggle()
        }
      } else if (cmd === "next") {
        Mpd.next()
      } else if (cmd === "prev") {
        Mpd.prev()
      } else if (cmd === "refresh") {
        Mpd.refresh()
      } else if (cmd.startsWith("play ")) {
        Mpd.playIndex(parseInt(cmd.slice(5)))
      } else if (cmd.startsWith("seek ")) {
        Mpd.seek(parseFloat(cmd.slice(5)))
      } else if (cmd.startsWith("volume ")) {
        Mpd.setVolume(parseFloat(cmd.slice(7)))
      } else if (cmd.startsWith("repeat ")) {
        Mpd.setRepeat(cmd.slice(7) === "on")
      } else if (cmd.startsWith("random ")) {
        Mpd.setRandom(cmd.slice(7) === "on")
      } else if (cmd.startsWith("single ")) {
        Mpd.setSingle(cmd.slice(7) === "on")
      } else {
        return "unknown"
      }
      return "ok"
    }

    function musicTab(index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return false
      }
      panel.switchTab(index)
      return true
    }

    function folderState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testFolderState()
      state.enabled = true
      return JSON.stringify(state)
    }

    function folderNavigate(path: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testFolderNavigate(path)
    }

    function folderSearch(query: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testFolderSearch(query)
    }

    function folderRowRect(index: int): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("music")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rect = panel.testFolderRowRect(index)
      if (!rect) {
        return "{\"enabled\":true,\"open\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.open = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function toggleSection(section: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleSection(section)
    }

    function setSectionExpanded(section: string, state: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetSection(section, state)
    }

    function setAppExpanded(app: string, state: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetApp(app, state)
    }

    function appRows(app: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rows = panel.testAppRows(app)
      if (!rows) {
        return "{\"enabled\":true,\"open\":true,\"found\":false}"
      }
      return JSON.stringify({
        enabled: true,
        open: true,
        found: true,
        rows: rows
      })
    }

    function routeStream(app: string, index: int, target: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testRouteStream(app, index, target)
    }

    function toggleApp(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      panel.toggleApp(name)
      return true
    }

    function pinDevice(kind: string, text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testPinDevice(kind, text)
    }

    function defaultDevice(kind: string, text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testDefaultDevice(kind, text)
    }

    function currentDevice(kind: string): string {
      if (!TestDriver.active) {
        return ""
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return ""
      }
      return panel.testCurrentDevice(kind)
    }

    function appNames(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const names = panel.testAppNames()
      return JSON.stringify({
        enabled: true,
        open: true,
        apps: names
      })
    }

    function toggleStreamPin(app: string, index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleStreamPin(app, index)
    }

    function pinApp(app: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("volume")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testPinApp(app)
    }

    function wifiState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testWifiState()
      state.enabled = true
      state.open = true
      return JSON.stringify(state)
    }

    function wifiBeginPass(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testBeginPassword(name)
    }

    function wifiSetPass(text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetPassword(text)
    }

    function wifiPassEcho(): string {
      if (!TestDriver.active) {
        return ""
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return ""
      }
      return panel.testPasswordEcho()
    }

    function wifiShowToggle(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleShowPassword()
    }

    function wifiPassRect(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const rect = panel.testPasswordRect()
      if (!rect) {
        return "{\"enabled\":true,\"open\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.open = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function wifiPassSubmit(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSubmitPassword()
    }

    function wifiForgetAsk(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testAskForget(name)
    }

    function wifiForgetConfirm(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testConfirmForget()
    }

    function wifiForgetCancel(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testCancelForget()
    }

    function wifiExpand(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleExpanded(name)
    }

    function wifiAutoToggle(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleAutoConnect(name)
    }

    function wifiQrToggle(name: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleSharing(name)
    }

    function wifiSpeedtest(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleSpeedtest()
    }

    function wifiSpeedtestMock(phase: string, down: real, up: real): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testMockSpeedtest(phase, down, up)
    }

    function wifiSpeedtestPreload(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testPreloadSpeedtest()
    }

    function wifiSectionToggle(section: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      panel.toggleSection(section)
      return true
    }

    function wifiSectionSet(section: string, state: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("network")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetSection(section, state)
    }

    function bluetoothState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testBluetoothState()
      state.enabled = true
      state.open = true
      return JSON.stringify(state)
    }

    function bluetoothSectionToggle(section: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleSection(section)
    }

    function bluetoothSectionSet(section: string, state: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetSection(section, state)
    }

    function bluetoothExpand(address: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleExpanded(address)
    }

    function bluetoothRemoveAsk(address: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testAskRemove(address)
    }

    function bluetoothRemoveConfirm(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testConfirmRemove()
    }

    function bluetoothRemoveCancel(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testCancelRemove()
    }

    function bluetoothTrusted(address: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleTrusted(address)
    }

    function bluetoothConnected(address: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("bluetooth")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testToggleConnected(address)
    }

    function panelRect(name: string, screen: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const rect = TestDriver.panelRect(name, screen)
      if (!rect) {
        return "{\"enabled\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function barRect(screen: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const rect = TestDriver.barRect(screen)
      if (!rect) {
        return "{\"enabled\":true,\"found\":false}"
      }
      rect.enabled = true
      rect.found = true
      return JSON.stringify(rect)
    }

    function shotPanel(name: string, screen: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const rect = TestDriver.panelRect(name, screen)
      if (!rect) {
        return "{\"enabled\":true,\"found\":false}"
      }
      const shot = TestDriver.runShot(rect)
      shot.enabled = true
      shot.found = true
      return JSON.stringify(shot)
    }

    function shotBar(screen: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const rect = TestDriver.barRect(screen)
      if (!rect) {
        return "{\"enabled\":true,\"found\":false}"
      }
      const shot = TestDriver.runShot(rect)
      shot.enabled = true
      shot.found = true
      return JSON.stringify(shot)
    }

    function shotPoll(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const result = TestDriver.shotResult
      result.enabled = true
      return JSON.stringify(result)
    }

    function launcherQuery(text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetQuery(text)
    }

    function launcherSelect(index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSelect(index)
    }

    function launcherState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testState()
      state.enabled = true
      state.open = true
      return JSON.stringify(state)
    }

    function launcherEval(expression: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      return JSON.stringify(panel.testEval(expression))
    }

    function launcherKitty(command: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      return JSON.stringify(panel.testKittyArgv(command))
    }

    function launcherActivate(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testActivate()
    }

    function launcherDebug(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const debug = panel.testDebug()
      debug.enabled = true
      debug.open = true
      return JSON.stringify(debug)
    }

    function launcherFavorite(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testFavorite()
    }

    function launcherBackspace(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testBackspace()
    }

    function launcherVisibleTarget(offset: int): int {
      if (!TestDriver.active) {
        return -2
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return -2
      }
      return panel.testVisibleTarget(offset)
    }

    function launcherProviderMock(key: string, payload: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testProviderMock(key, payload)
    }

    function launcherParamState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const state = panel.testParams()
      state.enabled = true
      state.open = true
      state.candidates = panel.testParamCandidates()
      return JSON.stringify(state)
    }

    function launcherSetParam(key: string, text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testSetParam(key, text)
    }

    function launcherFocusParam(key: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testFocusParam(key)
    }

    function launcherFocusTerm(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testFocusTerm()
    }

    function launcherParamFocus(direction: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testMoveParamFocus(direction)
    }

    function launcherCandidateStep(direction: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testCandidateStep(direction)
    }

    function launcherCandidateAccept(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testPickParam(0)
    }

    function launcherParamKey(name: string, modifier: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testParamKey(name, modifier)
    }

    function launcherTypeParam(text: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testTypeParam(text)
    }

    function launcherProviderUrl(key: string): string {
      if (!TestDriver.active) {
        return ""
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return ""
      }
      return panel.testProviderUrl(key)
    }

    function launcherValidate(spec: string, raw: string): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      const parsed = JSON.parse(spec)
      return JSON.stringify(panel.testValidate(parsed, raw))
    }

    function procRows(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("battery")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      return JSON.stringify(panel.testProcRows())
    }

    function procMenu(row: int): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("battery")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testProcMenu(row)
    }

    function procMenuState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const panel = TestDriver.panel("battery")
      if (!panel || !panel.open) {
        return "{\"enabled\":true,\"open\":false}"
      }
      return JSON.stringify(panel.testProcMenuState())
    }

    function procMenuInvoke(index: int): string {
      if (!TestDriver.active) {
        return ""
      }
      const panel = TestDriver.panel("battery")
      if (!panel || !panel.open) {
        return ""
      }
      return panel.testProcMenuInvoke(index)
    }

    function procMenuClose(): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("battery")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testProcMenuClose()
    }

    function procRowRect(row: int): string {
      if (!TestDriver.active) {
        return "{}"
      }
      const panel = TestDriver.panel("battery")
      if (!panel || !panel.open) {
        return "{}"
      }
      const local = panel.testProcRowRect(row)
      if (!local) {
        return "{}"
      }
      const mon = TestDriver.monitorRect(panel.screenId)
      if (!mon) {
        return "{}"
      }
      return JSON.stringify({
        x: mon.x + Math.round(local.x),
        y: mon.y + Math.round(local.y),
        width: Math.round(local.width),
        height: Math.round(local.height),
        monitor: mon.name
      })
    }

    function notifState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const model = Notifs.active
      const vals = model && model.values ? model.values : []
      const act = []
      for (let i = 0; i < vals.length; i++) {
        const n = vals[i]
        act.push({
          id: n.id,
          app: n.appName,
          summary: n.summary,
          body: n.body,
          urgency: n.urgency,
          sticky: Notifs.isSticky(n),
          remaining: Notifs.remainingFor(n),
          hoverPause: Notifs.hoverPaused(n)
        })
      }
      const recs = []
      for (let i = 0; i < Notifs.records.length; i++) {
        recs.push({
          body: Notifs.records[i].snap.body,
          remaining: Math.round(Notifs.records[i].remaining),
          sticky: Notifs.records[i].sticky
        })
      }
      return JSON.stringify({
        enabled: true,
        dnd: Notifs.dnd,
        idle: Notifs.idle,
        locked: Notifs.locked,
        lastError: Notifs.lastError,
        recordCount: Notifs.records.length,
        records: recs,
        activeCount: act.length,
        active: act,
        unread: NotifStore.unreadCount,
        lastSeen: NotifStore.lastSeen,
        ready: NotifStore.ready,
        exhausted: NotifStore.exhausted,
        historyCount: NotifStore.history.length
      })
    }

    function bannerState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const b = Notifs.bannerSelected
      const rows = []
      for (let i = 0; i < Notifs.bannerRows.length; i++) {
        const r = Notifs.bannerRows[i]
        rows.push({
          app: r.snap.appName,
          summary: r.snap.summary,
          urgency: r.snap.urgency
        })
      }
      const base = {
        enabled: true,
        present: Notifs.bannerVisible,
        phase: Notifs.bannerPhase,
        count: Notifs.bannerCount,
        more: Notifs.bannerMore,
        rows: rows,
        selectedIndex: Notifs.selectedIndex(),
        critical: Notifs.bannerCritical,
        criticalRemaining: Math.round(Notifs.bannerCriticalRemaining),
        remaining: Math.round(Notifs.bannerRemaining),
        suppressed: Notifs.bannerSuppressed(),
        deferred: Notifs.bannerDeferred,
        acknowledged: Notifs.bannerAcknowledged,
        hover: Notifs.bannerHover,
        unread: NotifStore.unreadCount
      }
      const panel = TestDriver.panel("banner", "eDP-1")
      if (panel) {
        base.metrics = panel.testMetrics()
      }
      if (!b) {
        return JSON.stringify(base)
      }
      const acts = []
      for (let j = 0; j < b.snap.actions.length; j++) {
        acts.push(b.snap.actions[j])
      }
      base.app = b.snap.appName
      base.summary = b.snap.summary
      base.body = b.snap.body
      base.urgency = b.snap.urgency
      base.actions = acts
      base.hasImage = String(b.snap.image || "").length > 0
      return JSON.stringify(base)
    }

    function bannerShot(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      const rect = TestDriver.panelRect("banner", "eDP-1")
      if (!rect) {
        return JSON.stringify({
          enabled: true,
          found: false
        })
      }
      const shot = TestDriver.runShot(rect)
      shot.enabled = true
      shot.found = true
      return JSON.stringify(shot)
    }

    function bannerDismiss(): bool {
      if (!TestDriver.active) {
        return false
      }
      return Notifs.dismissBannerSelected()
    }

    function bannerSelect(index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      return Notifs.selectBannerIndex(index)
    }

    function bannerSelectRow(index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      return Notifs.selectBannerRow(index)
    }

    function bannerDismissRow(index: int): bool {
      if (!TestDriver.active) {
        return false
      }
      return Notifs.dismissBannerRow(index)
    }

    function bannerInvoke(zone: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("banner", "eDP-1")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testInvoke(zone)
    }

    function bannerHold(enabled: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      Notifs.setBannerHold(enabled)
      return Notifs.bannerHold
    }

    function bannerHover(enabled: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      Notifs.setBannerHover(enabled)
      return Notifs.bannerHover
    }

    function bannerAdvance(ms: int): bool {
      if (!TestDriver.active) {
        return false
      }
      Notifs.advanceBanner(ms)
      return true
    }

    function bannerDismissAll(): bool {
      if (!TestDriver.active) {
        return false
      }
      Notifs.dismissAll()
      return true
    }

    function notifQuery(sql: string): bool {
      if (!TestDriver.active) {
        return false
      }
      NotifStore.runRaw(sql)
      return true
    }

    function notifDnd(enabled: bool): bool {
      if (!TestDriver.active) {
        return false
      }
      Notifs.dnd = enabled
      return Notifs.dnd
    }

    function notifRaw(): string {
      if (!TestDriver.active) {
        return "{}"
      }
      return JSON.stringify({
        seq: NotifStore.rawSeq,
        code: NotifStore.rawCode,
        out: NotifStore.lastRaw
      })
    }

    function lockPreview(open: string): bool {
      if (!TestDriver.active) {
        return false
      }
      if (open === "true") {
        LockState.openPreview()
      } else if (open === "false") {
        LockState.closePreview()
      } else {
        LockState.togglePreview()
      }
      return LockState.previewActive
    }

    function lockAttempt(password: string): string {
      if (!TestDriver.active) {
        return "disabled"
      }
      return LockState.testAttempt(password)
    }

    function lockState(): string {
      if (!TestDriver.active) {
        return "{\"enabled\":false}"
      }
      return LockState.testState()
    }
  }

  WlSessionLock {
    id: sessionLock

    locked: LockState.sessionLocked

    onSecureChanged: LockState.secure = sessionLock.secure

    onLockStateChanged: {
      if (!sessionLock.locked && LockState.sessionLocked) {
        LockState.unlock()
      }
    }

    surface: Component {
      LockSurface {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Bar {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Dashboard {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      NetworkPanel {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      BluetoothPanel {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      VolumePanel {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      BatteryPanel {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      MusicPanel {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      NotificationsPanel {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      Launcher {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PowerMenu {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      WindowSwitcher {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PolkitPrompt {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      OsdPopup {}
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      LockPreview {}
    }
  }
}
