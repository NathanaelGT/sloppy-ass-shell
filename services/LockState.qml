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
  property bool captureInFlight: false
  property string captureMode: ""
  property int attempts: 0
  property int captureSeq: 0
  property int captureGen: 0
  property int procCaptureGen: 0
  property string error: ""
  property string pendingPassword: ""
  property string fieldText: ""
  property var captures: ({})
  property var captureTargets: []
  property var previewScreen: null
  property var lockScreens: []

  readonly property string captureDir: Quickshell.stateDir + "/lock"
  readonly property string grimPath: "/etc/profiles/per-user/nathanaelgt/bin/grim"

  function captureFor(screen) {
    const entry = root.captures[screen]
    return entry ? entry : {
      state: "idle",
      path: ""
    }
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
    if (root.sessionLocked || root.previewActive || root.captureInFlight) {
      return
    }
    root.attempts = 0
    root.error = ""
    root.fieldText = ""
    root.readCaps()
    root.startCapture("preview", ["eDP-1"])
  }

  function closePreview() {
    if (!root.previewActive) {
      return
    }
    root.previewActive = false
    root.attempts = 0
    root.error = ""
    root.fieldText = ""
  }

  function requestLock() {
    if (root.sessionLocked || root.captureInFlight) {
      return
    }
    root.closePreview()
    Panels.close()
    root.readCaps()
    root.startCapture("lock", root.screenNames())
  }

  function lockAndSuspend() {
    if (root.sessionLocked || root.captureInFlight) {
      return
    }
    root.closePreview()
    Panels.close()
    root.readCaps()
    root.startCapture("suspend", root.screenNames())
  }

  function screenNames() {
    const out = []
    for (let i = 0; i < Quickshell.screens.length; i++) {
      out.push(Quickshell.screens[i].name)
    }
    return out
  }

  function startCapture(mode, screens) {
    root.captureMode = mode
    root.captureSeq += 1
    root.captureGen = root.captureSeq
    root.captures = {}
    root.captureTargets = screens
    const next = {}
    for (let i = 0; i < screens.length; i++) {
      next[screens[i]] = {
        state: "pending",
        path: root.captureDir + "/" + screens[i] + ".png"
      }
    }
    root.captures = next
    let script = "mkdir -p " + root.captureDir + "\n"
    for (let j = 0; j < screens.length; j++) {
      const name = screens[j]
      const file = root.captureDir + "/" + name + ".png"
      script += "timeout 2 " + root.grimPath + " -o '" + name + "' '" + file + "' && timeout 2 ffmpeg -y -loglevel error -i '" + file + "' -vf \"scale=iw/6:ih/6,boxblur=luma_radius=8:luma_power=2,scale=iw*6:ih*6\" '" + file + ".tmp.png' && mv '" + file + ".tmp.png' '" + file + "' && echo 'ok " + name + "' || echo 'fail " + name + "'\n"
    }
    captureProc.command = ["bash", "-c", script]
    if (captureProc.running) {
      captureProc.terminate()
    }
    root.procCaptureGen = root.captureGen
    captureProc.running = true
    root.captureInFlight = true
    captureTimer.restart()
  }

  function parseCapture(text) {
    if (root.procCaptureGen !== root.captureGen || !root.captureInFlight) {
      return
    }
    if (text) {
      const lines = text.split("\n")
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim()
        if (line === "") {
          continue
        }
        const parts = line.split(" ")
        if (parts.length < 2 || root.captures[parts[1]] === undefined) {
          continue
        }
        const next = {}
        for (const k in root.captures) {
          next[k] = root.captures[k]
        }
        next[parts[1]] = {
          state: parts[0] === "ok" ? "captured" : "failed",
          path: root.captures[parts[1]].path
        }
        root.captures = next
      }
    }
    for (const k in root.captures) {
      if (root.captures[k].state === "pending") {
        return
      }
    }
    root.captureDone()
  }

  function captureTimedOut() {
    if (!root.captureInFlight) {
      return
    }
    const next = {}
    for (const k in root.captures) {
      const entry = root.captures[k]
      next[k] = {
        state: entry.state === "pending" ? "failed" : entry.state,
        path: entry.path
      }
    }
    root.captures = next
    root.captureDone()
  }

  function captureDone() {
    root.captureInFlight = false
    captureTimer.stop()
    if (root.captureMode === "preview") {
      root.previewActive = true
    } else if (root.captureMode === "lock" || root.captureMode === "suspend") {
      root.engage()
      if (root.captureMode === "suspend") {
        Quickshell.execDetached(["systemctl", "suspend"])
      }
    }
  }

  function engage() {
    if (root.sessionLocked) {
      return
    }
    root.sessionLocked = true
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
      passwordLength: screen ? screen.fieldLength : 0,
      capture: {
        mode: root.captureMode,
        inFlight: root.captureInFlight,
        screens: root.captures
      }
    })
  }

  onSessionLockedChanged: {
    Notifs.locked = root.sessionLocked
    if (root.sessionLocked) {
      Panels.close()
    }
  }

  Component.onCompleted: {
    Quickshell.execDetached(["bash", "-lc", "loginctl show-session self -p LockedHint | grep -q yes && busctl call --system org.freedesktop.login1 /org/freedesktop/login1/session/self org.freedesktop.login1.Session SetLockedHint b false || true"])
    Quickshell.execDetached(["mkdir", "-p", root.captureDir])
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
    id: captureProc

    stdout: StdioCollector {
      id: captureOut

      onStreamFinished: root.parseCapture(captureOut.text)
    }

    onExited: root.parseCapture(null)
  }

  Process {
    id: capsProc

    stdout: StdioCollector {
      id: capsOut

      onStreamFinished: root.capsLock = capsOut.text.trim() === "1"
    }
  }

  Timer {
    id: captureTimer

    interval: 5000
    onTriggered: root.captureTimedOut()
  }
}
