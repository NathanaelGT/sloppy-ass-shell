pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Singleton {
  id: root

  property bool previewActive: false
  property bool sessionLocked: false
  property bool secure: false
  property bool authenticating: false
  property bool capsLock: false
  property int attempts: 0
  property string error: ""
  property string pendingPassword: ""
  property string fieldText: ""
  property var previewScreen: null
  property var lockScreens: []
  property int lastTriggerSeq: 0
  property bool triggerArmed: false

  readonly property int blurLockSize: 12
  readonly property int blurLockPasses: 3
  readonly property int blurRestSize: 3
  readonly property int blurRestPasses: 1
  readonly property string triggerPath: Quickshell.stateDir + "/../../lock-trigger"

  function applyBlur() {
    Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { size = " + root.blurLockSize + ", passes = " + root.blurLockPasses + " } } })"])
  }

  function restoreBlur() {
    Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { size = " + root.blurRestSize + ", passes = " + root.blurRestPasses + " } } })"])
  }

  function noteScreen(screen) {
    if (screen.preview) {
      root.previewScreen = screen
    } else {
      root.lockScreens = root.lockScreens.concat([screen])
    }
  }

  function forgetScreen(screen) {
    if (screen.preview) {
      if (root.previewScreen === screen) {
        root.previewScreen = null
      }
      return
    }
    root.lockScreens = root.lockScreens.filter(s => s !== screen)
  }

  function activeScreen() {
    if (root.previewActive && root.previewScreen) {
      return root.previewScreen
    }
    if (root.sessionLocked && root.lockScreens.length > 0) {
      return root.lockScreens[0]
    }
    return null
  }

  function togglePreview() {
    if (root.previewActive) {
      root.closePreview()
    } else {
      root.openPreview()
    }
  }

  function openPreview() {
    if (root.sessionLocked || root.previewActive) {
      return
    }
    root.attempts = 0
    root.error = ""
    root.fieldText = ""
    root.readCaps()
    root.applyBlur()
    root.previewActive = true
  }

  function closePreview() {
    if (!root.previewActive) {
      return
    }
    root.previewActive = false
    root.attempts = 0
    root.error = ""
    root.fieldText = ""
    blurRestoreAnim.startRestore()
  }

  function requestLock() {
    if (root.sessionLocked) {
      return
    }
    root.closePreview()
    Panels.close()
    root.readCaps()
    root.engage()
  }

  function lockAndSuspend() {
    if (!root.sessionLocked) {
      root.closePreview()
      Panels.close()
      root.readCaps()
      root.engage()
    }
    Quickshell.execDetached(["systemctl", "suspend"])
  }

  function engage() {
    if (root.sessionLocked) {
      return
    }
    root.applyBlur()
    root.sessionLocked = true
    root.secure = true
    root.setLockedHint(true)
  }

  function setLockedHint(state) {
    Quickshell.execDetached(["busctl", "call", "--system", "org.freedesktop.login1", "/org/freedesktop/login1/session/self", "org.freedesktop.login1.Session", "SetLockedHint", "b", state ? "true" : "false"])
  }

  function unlock() {
    if (!root.sessionLocked) {
      return
    }
    root.sessionLocked = false
    root.secure = false
    root.attempts = 0
    root.error = ""
    root.fieldText = ""
    root.setLockedHint(false)
    blurRestoreAnim.startRestore()
  }

  function submit(password) {
    if (root.authenticating) {
      return false
    }
    if (password === "") {
      return false
    }
    root.pendingPassword = password
    root.authenticating = true
    root.error = ""
    if (pam.start()) {
      return true
    }
    root.authenticating = false
    root.pendingPassword = ""
    if (root.error === "") {
      root.error = "Authentication unavailable"
    }
    return true
  }

  function finishSuccess() {
    root.attempts = 0
    root.error = ""
    root.fieldText = ""
    if (root.previewActive) {
      root.closePreview()
      return
    }
    if (root.sessionLocked) {
      root.unlock()
    }
  }

  function finishFailure(message) {
    root.authenticating = false
    root.pendingPassword = ""
    root.attempts += 1
    root.fieldText = ""
    if (message !== "") {
      root.error = message
    }
  }

  function readCaps() {
    capsProc.command = ["bash", "-c", "v=0; for f in /sys/class/leds/*::capslock/brightness; do [ -r \"$f\" ] && [ \"$(cat \"$f\")\" != \"0\" ] && v=1; done; echo $v"]
    capsProc.running = true
  }

  function testAttempt(password) {
    const screen = root.activeScreen()
    if (!screen) {
      return "no-lock"
    }
    if (!screen.acceptInput) {
      return "not-secure"
    }
    screen.testSetPassword(password)
    if (!screen.submitField()) {
      return root.authenticating ? "busy" : "empty"
    }
    return "submitted"
  }

  function testState() {
    const screen = root.activeScreen()
    return JSON.stringify({
      enabled: true,
      preview: root.previewActive,
      locked: root.sessionLocked,
      secure: root.secure,
      attempts: root.attempts,
      error: root.error,
      capsLock: root.capsLock,
      authenticating: root.authenticating,
      passwordLength: screen ? screen.fieldLength : 0
    })
  }

  function handleTrigger() {
    const parts = triggerView.text().trim().split(" ")
    if (parts[0] !== "lock" && parts[0] !== "suspend") {
      return
    }
    const seq = parseInt(parts[1])
    if (isNaN(seq) || seq <= root.lastTriggerSeq) {
      return
    }
    root.lastTriggerSeq = seq
    if (!root.triggerArmed) {
      root.triggerArmed = true
      return
    }
    if (parts[0] === "lock") {
      root.requestLock()
    } else {
      root.lockAndSuspend()
    }
  }

  onSessionLockedChanged: {
    Notifs.locked = root.sessionLocked
    if (root.sessionLocked) {
      Panels.close()
    }
  }

  Component.onCompleted: {
    Quickshell.execDetached(["bash", "-lc", "loginctl show-session self -p LockedHint | grep -q yes && busctl call --system org.freedesktop.login1 /org/freedesktop/login1/session/self org.freedesktop.login1.Session SetLockedHint b false || true"])
    Quickshell.execDetached(["touch", root.triggerPath])
  }

  Timer {
    id: blurRestoreAnim

    interval: 50
    repeat: true
    property int step: 0
    readonly property int steps: 9

    function startRestore() {
      step = 0
      restart()
    }

    onTriggered: {
      if (root.sessionLocked || root.previewActive) {
        stop()
        step = 0
        return
      }
      step += 1
      if (step >= steps) {
        stop()
        step = 0
        root.restoreBlur()
        return
      }
      const size = Math.max(0, Math.round(root.blurLockSize * (1 - step / steps)))
      Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { size = " + size + " } } })"])
    }
  }

  FileView {
    id: triggerView

    path: root.triggerPath
    watchChanges: true

    onFileChanged: this.reload()

    onLoaded: root.handleTrigger()
  }

  PamContext {
    id: pam

    config: "quickshell"
    configDirectory: Quickshell.configDir + "/pam.d"

    onPamMessage: {
      if (pam.responseRequired && root.pendingPassword !== "") {
        pam.respond(root.pendingPassword)
      }
    }

    onCompleted: result => {
      if (result === PamResult.Success) {
        root.authenticating = false
        root.pendingPassword = ""
        root.finishSuccess()
      } else if (result === PamResult.Error) {
        root.finishFailure("")
      } else {
        root.finishFailure("")
      }
    }

    onError: err => {
      root.finishFailure("Authentication unavailable")
    }
  }

  Process {
    id: capsProc

    stdout: StdioCollector {
      id: capsOut

      onStreamFinished: root.capsLock = capsOut.text.trim() === "1"
    }
  }
}
