import QtQuick
import Quickshell
import Quickshell.Io
import "theme"
import "services"
import "bar"
import "panels"
import "osd"
import "notifications"

ShellRoot {
  id: root

  property string lastReloadError: ""
  property bool suppressReloadPopup: false

  Component.onCompleted: Quickshell.watchFiles = false

  function workToast(urgency, title, body) {
    Quickshell.execDetached(["dunstify", "-a", "opencode", "-u", urgency, title, body])
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

    function launcher(): void {
      Panels.toggle("launcher", Hypr.focusedScreenName)
    }

    function session(): void {
      Panels.toggle("session", Hypr.focusedScreenName)
    }

    function controlCenter(): void {
      Panels.toggle("control-center", Hypr.focusedScreenName)
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

    function notifications(): void {
      Panels.toggle("notifications", Hypr.focusedScreenName)
    }

    function windowSwitcher(): void {
      Panels.toggle("window-switcher", Hypr.focusedScreenName)
    }

    function close(): void {
      Panels.close()
    }

    function reload(): void {
      Quickshell.reload(false)
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

    function closePanel(): bool {
      if (!TestDriver.active) {
        return false
      }
      Panels.close()
      return true
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
        screen: panel.screenId
      })
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

    function launcherOlMock(payload: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testOlMock(payload)
    }

    function launcherTrMock(payload: string): bool {
      if (!TestDriver.active) {
        return false
      }
      const panel = TestDriver.panel("launcher")
      if (!panel || !panel.open) {
        return false
      }
      return panel.testTrMock(payload)
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
      ControlCenter {}
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
      SessionMenu {}
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
      Toasts {}
    }
  }
}
