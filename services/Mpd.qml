pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
  id: root

  property string host: Quickshell.env("MPD_HOST") || "127.0.0.1"
  property int port: {
    const p = parseInt(Quickshell.env("MPD_PORT"))
    return isNaN(p) ? 6600 : p
  }
  property string socketPath: {
    if (root.host.indexOf("/") >= 0) {
      return root.host
    }
    return (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/mpd/socket"
  }

  property string musicDir: ""
  property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/music/state.json"
  property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/music"

  property bool greeted: false
  property string version: ""
  property string state: "stop"
  property var song: null
  property real elapsed: 0
  property bool repeat: false
  property int bitrate: 0
  property string audioFormat: ""
  property bool random: false
  property bool single: false
  property var queue: []
  property int artIndex: 0
  property bool idleInFlight: false
  property var awaiting: null
  property var sendQueue: []
  property bool clearingQueue: false

  property var favorites: ({})
  property var pinned: ({})
  property string playSource: ""
  property bool weightedRandom: false
  property int lastTab: 0
  property string coverPath: ""
  property var trackCovers: ({})
  property var trackCoverQueue: []

  property var folders: ({})
  property var counts: ({})
  property var songsByUri: ({})
  property bool allSongsLoaded: false

  readonly property bool connected: greeted
  readonly property real duration: song ? song.duration : 0
  readonly property string streamName: "mpd.music"
  readonly property var streamNode: {
    const nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (let i = 0; i < nodes.length; i++) {
      const props = nodes[i].properties
      if (props && props["node.name"] === root.streamName) {
        return nodes[i]
      }
    }
    return null
  }
  readonly property var streamAudio: root.streamNode ? root.streamNode.audio : null
  readonly property int volume: root.streamAudio ? Math.min(100, Math.round(root.streamAudio.volume * 100)) : -1
  property int lastVolume: 0
  property real streamSince: 0
  property real songChangedAt: 0
  property real elapsedBase: 0
  property real elapsedAt: 0

  function setElapsed(seconds) {
    root.elapsedBase = seconds
    root.elapsedAt = Date.now()
    root.elapsed = seconds
  }
  onStreamAudioChanged: {
    if (root.streamAudio) {
      root.streamSince = Date.now()
      volumeSettleTimer.restart()
      if (root.restoreVolume > 0) {
        root.setVolume(root.restoreVolume)
        root.restoreVolume = -1
      }
    }
  }
  onVolumeChanged: {
    if (root.fading) {
      return
    }
    if (root.volume > 0 || (root.volume >= 0 && Date.now() - root.streamSince > 300)) {
      root.lastVolume = root.volume
    }
  }
  readonly property bool fading: fadeTimer.running || restoreTimer.running
  property real fadeFrom: 0
  property real fadeTo: 0
  property real fadeAnchor: 0
  property real fadeStart: 0
  property int fadeDuration: 500
  property var fadeDone: null
  property real restoreVolume: -1
  readonly property int displayVolume: root.fading ? Math.max(0, Math.round(root.fadeAnchor)) : (root.volume > 0 || (root.volume >= 0 && Date.now() - root.streamSince > 300) ? root.volume : Math.max(0, root.lastVolume))
  readonly property bool streamStable: root.streamNode !== null || streamGraceTimer.running
  onStreamNodeChanged: {
    if (!root.streamNode) {
      streamGraceTimer.restart()
    }
  }
  readonly property var coverNames: ["cover.jpg", "cover.png", "folder.jpg", "folder.png", "front.jpg", "front.png", "album.jpg", "album.png"]
  readonly property string artUrl: root.coverPath.length > 0 ? ("file://" + root.coverPath) : ""

  function esc(s) {
    if (s === null || s === undefined) {
      return ""
    }
    return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  }

  function baseName(file) {
    if (!file) {
      return ""
    }
    const slash = file.lastIndexOf("/")
    return slash >= 0 ? file.slice(slash + 1) : file
  }

  function parentDir(file) {
    if (!file) {
      return ""
    }
    const slash = file.lastIndexOf("/")
    return slash >= 0 ? file.slice(0, slash) : ""
  }

  function parseFileTags(file) {
    const base = baseName(file)
    const dot = base.lastIndexOf(".")
    const name = dot > 0 ? base.slice(0, dot) : base
    const idx = name.indexOf(" - ")
    if (idx > 0) {
      return {
        artist: name.slice(0, idx).trim(),
        title: name.slice(idx + 3).trim()
      }
    }
    return {
      artist: "",
      title: name.trim()
    }
  }

  function toNum(value) {
    const n = parseFloat(value)
    return isNaN(n) ? 0 : n
  }

  function toInt(value, fallback) {
    const n = parseInt(value)
    return isNaN(n) ? (fallback === undefined ? 0 : fallback) : n
  }

  function parsePairs(lines) {
    const out = {}
    for (let i = 0; i < lines.length; i++) {
      const idx = lines[i].indexOf(": ")
      if (idx > 0) {
        const key = lines[i].slice(0, idx)
        if (out[key] === undefined) {
          out[key] = lines[i].slice(idx + 2)
        }
      }
    }
    return out
  }

  function parseSongs(lines) {
    const out = []
    let current = null
    for (let i = 0; i < lines.length; i++) {
      const idx = lines[i].indexOf(": ")
      if (idx <= 0) {
        continue
      }
      const key = lines[i].slice(0, idx)
      const value = lines[i].slice(idx + 2)
      if (key === "file") {
        current = {
          file: value
        }
        out.push(current)
      } else if (current !== null && current[key] === undefined) {
        current[key] = value
      }
    }
    return out
  }

  function parseLsInfo(lines) {
    const out = []
    let cur = null
    for (let i = 0; i < lines.length; i++) {
      const idx = lines[i].indexOf(": ")
      if (idx <= 0) {
        continue
      }
      const key = lines[i].slice(0, idx)
      const value = lines[i].slice(idx + 2)
      if (key === "directory") {
        out.push({
          type: "dir",
          name: value.split("/").pop(),
          path: value
        })
        cur = null
      } else if (key === "file") {
        cur = {
          type: "file",
          name: value.split("/").pop(),
          path: value,
          title: "",
          artist: "",
          duration: 0
        }
        out.push(cur)
      } else if (cur) {
        if (key === "Title") {
          cur.title = value
        } else if (key === "Artist" || key === "AlbumArtist") {
          if (!cur.artist) {
            cur.artist = value
          }
        } else if (key === "Time") {
          cur.duration = root.toNum(value)
        } else if (key === "Album") {
          cur.album = value
        }
      }
    }
    for (let i = 0; i < out.length; i++) {
      if (out[i].type !== "file" || (out[i].title && out[i].artist)) {
        continue
      }
      const tags = root.parseFileTags(out[i].path)
      if (!out[i].title) {
        out[i].title = tags.title
      }
      if (!out[i].artist) {
        out[i].artist = tags.artist
      }
    }
    return out
  }

  function parseCount(lines) {
    const p = root.parsePairs(lines)
    return {
      songs: root.toInt(p.songs, 0),
      playtime: root.toInt(p.playtime, 0)
    }
  }

  function parseStickerFind(lines) {
    const set = {}
    const uris = []
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (line.indexOf("file: ") === 0) {
        const uri = line.slice(6)
        uris.push(uri)
      }
    }
    for (let i = 0; i < uris.length; i++) {
      set[uris[i]] = true
    }
    return set
  }

  function reset() {
    root.greeted = false
    root.version = ""
    root.awaiting = null
    root.sendQueue = []
    root.idleInFlight = false
    root.state = "stop"
    root.song = null
    root.bitrate = 0
    root.audioFormat = ""
    root.setElapsed(0)
    root.repeat = false
    root.random = false
    root.single = false
    root.queue = []
    root.musicDir = ""
    root.artIndex = 0
    root.favorites = ({})
    root.pinned = ({})
    root.folders = ({})
    root.counts = ({})
    root.songsByUri = ({})
    root.allSongsLoaded = false
    root.coverPath = ""
  }

  function write(text) {
    if (sockLoader.item) {
      sockLoader.item.write(text)
    }
  }

  function onLine(line) {
    if (!root.greeted) {
      if (line.indexOf("OK MPD") === 0) {
        root.greeted = true
        root.version = line.slice(7)
        root.bootstrap()
      } else {
        console.warn("mpd: unexpected greeting:" + line)
        if (sockLoader.item) {
          sockLoader.item.connected = false
        }
      }
      return
    }
    if (root.awaiting === null) {
      return
    }
    if (line === "OK") {
      const done = root.awaiting
      root.awaiting = null
      if (done.command === "idle") {
        root.idleInFlight = false
      }
      if (done.callback) {
        done.callback(done.lines)
      }
      root.pump()
    } else if (line.indexOf("ACK") === 0) {
      const failed = root.awaiting
      root.awaiting = null
      if (failed.command === "idle") {
        root.idleInFlight = false
      }
      console.warn("mpd:" + (failed.command || "") + " failed:" + line)
      root.pump()
    } else {
      root.awaiting.lines.push(line)
    }
  }

  function send(command, callback) {
    root.sendQueue.push({
      command: command,
      callback: callback
    })
    if (root.idleInFlight) {
      root.write("noidle\n")
    } else {
      root.pump()
    }
  }

  function pump() {
    if (!root.greeted || root.awaiting !== null) {
      return
    }
    if (root.sendQueue.length > 0) {
      const next = root.sendQueue.shift()
      root.awaiting = {
        command: next.command,
        callback: next.callback,
        lines: []
      }
      root.write(next.command + "\n")
      return
    }
    root.awaiting = {
      command: "idle",
      callback: root.onIdle,
      lines: []
    }
    root.idleInFlight = true
    root.write("idle player mixer options playlist database sticker\n")
  }

  function onIdle(lines) {
    let needStatus = false
    let needQueue = false
    let needDb = false
    let needSticker = false
    for (let i = 0; i < lines.length; i++) {
      const raw = lines[i]
      const system = raw.indexOf("changed: ") === 0 ? raw.slice(9) : raw
      if (system === "player" || system === "mixer" || system === "output" || system === "options") {
        needStatus = true
      } else if (system === "playlist") {
        needQueue = true
      } else if (system === "database") {
        needDb = true
      } else if (system === "sticker") {
        needSticker = true
      }
    }
    if (needStatus) {
      root.send("status", l => root.applyStatus(root.parsePairs(l)))
      root.send("currentsong", l => root.applySong(root.parseSongs(l)[0] || null))
    }
    if (needQueue) {
      root.send("playlistinfo", l => root.applyQueue(root.parseSongs(l)))
    }
    if (needSticker) {
      root.refreshStickers()
    }
    if (needDb) {
      root.folders = ({})
      root.counts = ({})
      root.songsByUri = ({})
      root.allSongsLoaded = false
      root.seedLibrary()
    }
  }

  function bootstrap() {
    root.send("config", l => root.applyConfig(root.parsePairs(l)))
    root.fetchStatus(true)
    root.send("currentsong", l => root.applySong(root.parseSongs(l)[0] || null))
    root.send("playlistinfo", l => root.applyQueue(root.parseSongs(l)))
    root.refreshStickers()
    root.loadState()
  }

  function applyConfig(pairs) {
    let dir = pairs.music_directory || ""
    if (dir.startsWith("\"") && dir.endsWith("\"")) {
      dir = dir.slice(1, -1)
    }
    root.musicDir = dir
  }

  function applyStatus(pairs, force) {
    const prevState = root.state
    root.state = pairs.state || "stop"
    root.repeat = pairs.repeat === "1"
    if (pairs.bitrate !== undefined) {
      root.bitrate = root.toInt(pairs.bitrate, 0)
    }
    if (pairs.audio !== undefined) {
      root.audioFormat = pairs.audio
    }
    root.random = pairs.random === "1"
    root.single = pairs.single !== undefined && pairs.single !== "0"
    if (pairs.time && (force || Date.now() - root.songChangedAt > 1000)) {
      root.setElapsed(root.toNum(pairs.time.split(":")[0]))
    }
    if (root.weightedRandom) {
      root.send("random 0", null)
    }
    if (root.state !== "play" && !root.fading && root.restoreVolume < 0 && root.streamAudio && root.volume === 0 && root.lastVolume > 0) {
      root.setVolume(root.lastVolume)
    }
    if (prevState === "play" && root.state === "stop" && !root.clearingQueue) {
      root.handleQueueEnd()
    }
  }

  function applySong(obj) {
    const id = obj ? root.toInt(obj.Id, -1) : -1
    const prevId = root.song ? root.song.id : -1
    const tags = obj ? root.parseFileTags(obj.file) : null
    root.song = obj ? {
      file: obj.file,
      title: obj.Title || tags.title || root.baseName(obj.file),
      artist: obj.Artist || obj.AlbumArtist || tags.artist || "",
      album: obj.Album || obj.AlbumTitle || "",
      duration: root.toNum(obj.Time),
      pos: root.toInt(obj.Pos, -1),
      id: id
    } : null
    if (id !== prevId) {
      root.songChangedAt = Date.now()
      root.fetchStatus(true)
      root.resolveCover()
    }
  }

  function applyQueue(lines) {
    root.queue = lines.map(s => {
      const tags = root.parseFileTags(s.file)
      return {
        pos: root.toInt(s.Pos, -1),
        id: root.toInt(s.Id, -1),
        file: s.file,
        title: s.Title || tags.title || root.baseName(s.file),
        artist: s.Artist || s.AlbumArtist || tags.artist || "",
        duration: root.toNum(s.Time)
      }
    })
  }

  function fetchStatus(force) {
    root.send("status", l => root.applyStatus(root.parsePairs(l), force))
  }

  function syncStatus() {
    root.fetchStatus(true)
  }

  function syncPlayer() {
    root.syncStatus()
    root.send("currentsong", l => root.applySong(root.parseSongs(l)[0] || null))
  }

  function syncAll() {
    root.syncPlayer()
    root.send("playlistinfo", l => root.applyQueue(root.parseSongs(l)))
  }

  function refresh() {
    if (!root.connected) {
      return
    }
    root.syncAll()
  }

  function updateDb() {
    if (!root.connected) {
      return
    }
    root.send("update", null)
  }

  function seedLibrary() {
    root.lsdir("", entries => {
      for (let i = 0; i < entries.length; i++) {
        if (entries[i].type !== "dir") {
          continue
        }
        root.lsdir(entries[i].path, () => {})
        root.fetchCount(entries[i].path, () => {})
      }
    })
    root.fetchCount("", () => {})
  }

  function toggle() {
    if (!root.connected) {
      return
    }
    if (fadeTimer.running) {
      fadeTimer.stop()
      root.fadeDone = null
      root.restoreVolume = -1
      root.setVolume(root.fadeAnchor)
      return
    }
    if (root.state === "play") {
      root.fadeOutPause()
    } else {
      root.fadeInPlay()
    }
  }

  function fadeOutPause() {
    if (!root.streamAudio) {
      root.send("pause 1")
      root.syncPlayer()
      return
    }
    const from = root.volume >= 0 ? root.volume : root.displayVolume
    if (from <= 0) {
      root.send("pause 1")
      root.syncPlayer()
      return
    }
    root.restoreVolume = from
    root.startFade(from, 0, () => {
      root.send("pause 1")
      restoreTimer.restart()
    })
  }

  function fadeInPlay() {
    const target = root.restoreVolume > 0 ? root.restoreVolume : (root.lastVolume > 0 ? root.lastVolume : Math.max(0, root.displayVolume))
    root.send("play")
    root.syncPlayer()
    if (root.streamAudio && target > 0) {
      root.restoreVolume = -1
      root.startFade(0, target, null)
    } else if (target > 0) {
      root.restoreVolume = target
    } else {
      root.restoreVolume = -1
    }
  }

  function startFade(from, to, done) {
    root.fadeFrom = from
    root.fadeTo = to
    root.fadeAnchor = Math.max(from, to)
    root.fadeStart = Date.now()
    root.fadeDone = done
    root.setVolume(from)
    fadeTimer.restart()
  }

  function next() {
    if (!root.connected) {
      return
    }
    root.send("next")
    root.syncPlayer()
  }

  function prev() {
    if (!root.connected) {
      return
    }
    root.send("previous")
    root.syncPlayer()
  }

  function seek(seconds) {
    if (!root.connected) {
      return
    }
    const target = Math.max(0, Math.round(seconds))
    root.setElapsed(target)
    root.send("seekcur " + target)
    root.syncStatus()
  }

  function setVolume(v) {
    if (!root.streamAudio) {
      return
    }
    root.streamAudio.volume = Math.max(0, Math.min(100, Math.round(v))) / 100
  }

  function setRepeatCycle() {
    if (!root.connected) {
      return
    }
    if (!root.repeat) {
      root.send("repeat 1")
      root.send("single 0")
    } else if (!root.single) {
      root.send("repeat 1")
      root.send("single 1")
    } else {
      root.send("repeat 0")
      root.send("single 0")
    }
    root.syncStatus()
  }

  function setRandomWeighted(on) {
    root.weightedRandom = on
    root.saveState()
    if (!on) {
      return
    }
    root.send("random 0", null)
    root.reorderRemaining()
  }

  function playFolder(dir) {
    root.playSource = dir
    root.saveState()
    if (root.weightedRandom) {
      root.clearAndPlayWeighted(dir)
    } else {
      root.beginClear()
      root.send("clear", null)
      root.send("add \"" + root.esc(dir) + "\"", null)
      root.send("play", null)
      root.syncAll()
    }
  }

  function playTracks(uris, source, startUri) {
    root.playSource = source
    root.saveState()
    root.beginClear()
    root.send("clear", null)
    for (let i = 0; i < uris.length; i++) {
      root.send("add \"" + root.esc(uris[i]) + "\"", null)
    }
    if (startUri !== undefined && startUri !== null && startUri.length > 0) {
      root.send("playlistinfo", l => {
        const songs = root.parseSongs(l)
        let pos = 0
        for (let i = 0; i < songs.length; i++) {
          if (songs[i].file === startUri) {
            pos = i
            break
          }
        }
        root.send("play " + pos, null)
        root.syncAll()
      })
    } else {
      root.send("play", null)
      root.syncAll()
    }
  }

  function playPinned(startUri) {
    root.playTracks(Object.keys(root.pinned), "pinned", startUri)
  }

  function playFavorites(startUri) {
    root.playTracks(Object.keys(root.favorites), "favorites", startUri)
  }

  function playAll() {
    root.playSource = "all"
    root.saveState()
    if (root.weightedRandom) {
      root.clearAndPlayWeighted("")
    } else {
      root.beginClear()
      root.send("clear", null)
      root.send("add \"\"", null)
      root.send("play", null)
      root.syncAll()
    }
  }

  function playFolderTrack(folder, uri) {
    const dir = folder === root.musicDir ? "" : folder
    root.playSource = folder
    root.saveState()
    root.beginClear()
    root.send("clear", null)
    root.send("add \"" + root.esc(dir) + "\"", null)
    root.send("playlistinfo", l => {
      const songs = root.parseSongs(l)
      let pos = 0
      for (let i = 0; i < songs.length; i++) {
        if (songs[i].file === uri) {
          pos = i
          break
        }
      }
      root.send("play " + pos, null)
      root.syncAll()
    })
  }

  function addTrack(uri) {
    root.send("add \"" + root.esc(uri) + "\"", null)
  }

  function playQueueId(id) {
    root.send("playid " + id, null)
    root.syncPlayer()
  }

  function deleteQueueId(id) {
    root.send("deleteid " + id, null)
    root.syncAll()
  }

  function moveQueueId(id, target) {
    root.send("moveid " + id + " " + target, null)
    root.syncAll()
  }

  function clearQueue() {
    root.beginClear()
    root.beginClear()
    root.send("clear", null)
    root.syncAll()
  }

  function beginClear() {
    root.clearingQueue = true
    clearGuardTimer.restart()
  }

  function handleQueueEnd() {
    if (root.queue.length === 0 || !root.song) {
      return
    }
    const finished = root.duration <= 0 || root.elapsed >= root.duration - 3 || root.song.pos === root.queue.length - 1
    if (!finished) {
      return
    }
    if (root.weightedRandom || root.random) {
      root.extendQueueRandom()
    } else {
      root.send("play 0", null)
      root.syncAll()
    }
  }

  function extendQueueRandom() {
    root.send("listallinfo", l => {
      const songs = root.parseSongs(l)
      const files = []
      for (let i = 0; i < songs.length; i++) {
        if (songs[i].file) {
          files.push(songs[i].file)
        }
      }
      const queued = {}
      for (let i = 0; i < root.queue.length; i++) {
        queued[root.queue[i].file] = true
      }
      let candidates = files.filter(f => !queued[f])
      if (candidates.length === 0) {
        const cur = root.song ? root.song.file : ""
        candidates = files.filter(f => f !== cur)
      }
      const scored = candidates.map(f => ({
            f: f,
            key: root.weightedKey(root.weightOf(f))
          }))
      scored.sort((a, b) => b.key - a.key)
      const picks = scored.slice(0, 10)
      const start = root.queue.length
      for (let i = 0; i < picks.length; i++) {
        root.send("add \"" + root.esc(picks[i].f) + "\"", null)
      }
      if (picks.length > 0) {
        root.send("play " + start, null)
      }
      root.syncAll()
    })
  }

  function lsdir(dir, cb) {
    const key = dir || ""
    if (root.folders[key] && root.folders[key].loaded) {
      if (cb) {
        cb(root.folders[key].entries)
      }
      return
    }
    root.send('lsinfo "' + root.esc(dir) + '"', l => {
      const entries = root.parseLsInfo(l)
      const next = Object.assign({}, root.folders)
      next[key] = {
        loaded: true,
        entries: entries
      }
      root.folders = next
      if (cb) {
        cb(entries)
      }
    })
  }

  function fetchCount(dir, cb) {
    const key = dir || ""
    if (root.counts[key]) {
      if (cb) {
        cb(root.counts[key])
      }
      return
    }
    root.send('count "(base \\"' + root.esc(dir) + '\\")"', l => {
      const c = root.parseCount(l)
      const next = Object.assign({}, root.counts)
      next[key] = c
      root.counts = next
      if (cb) {
        cb(c)
      }
    })
  }

  function loadAllSongs(cb) {
    if (root.allSongsLoaded) {
      if (cb) {
        cb()
      }
      return
    }
    root.send("listallinfo", l => {
      const songs = root.parseSongs(l)
      const map = {}
      for (let i = 0; i < songs.length; i++) {
        if (songs[i].file) {
          map[songs[i].file] = songs[i]
        }
      }
      root.songsByUri = map
      root.allSongsLoaded = true
      if (cb) {
        cb()
      }
    })
  }

  function collectionEntries(set) {
    const uris = Object.keys(set)
    const out = []
    for (let i = 0; i < uris.length; i++) {
      const uri = uris[i]
      const s = root.songsByUri[uri]
      const tags = root.parseFileTags(uri)
      out.push({
        type: "file",
        name: root.baseName(uri),
        path: uri,
        title: s && s.Title ? s.Title : tags.title,
        artist: s ? (s.Artist || s.AlbumArtist || tags.artist || "") : tags.artist,
        album: s && s.Album ? s.Album : "",
        duration: s ? root.toNum(s.Time) : 0
      })
    }
    return out
  }

  function searchSubtree(dir, query, cb) {
    const q = String(query)
    const fields = ["title", "artist", "album", "file"]
    const collected = []
    const seen = {}
    let remaining = fields.length
    for (let i = 0; i < fields.length; i++) {
      const field = fields[i]
      const cond = '(' + field + ' contains "' + root.esc(q) + '")'
      const expr = dir.length > 0 ? '((base "' + root.esc(dir) + '") AND ' + cond + ')' : cond
      root.send('search "' + root.esc(expr) + '"', l => {
        const songs = root.parseSongs(l)
        for (let j = 0; j < songs.length; j++) {
          const s = songs[j]
          if (seen[s.file]) {
            continue
          }
          seen[s.file] = true
          const tags = root.parseFileTags(s.file)
          collected.push({
            type: "file",
            name: root.baseName(s.file),
            path: s.file,
            title: s.Title || tags.title,
            artist: s.Artist || s.AlbumArtist || tags.artist || "",
            album: s.Album || "",
            duration: root.toNum(s.Time)
          })
        }
        remaining -= 1
        if (remaining === 0 && cb) {
          cb(collected)
        }
      })
    }
  }

  function refreshStickers() {
    root.send('sticker find song "" favorite', l => {
      root.favorites = root.parseStickerFind(l)
    })
    root.send('sticker find song "" pinned', l => {
      root.pinned = root.parseStickerFind(l)
    })
  }

  function setFavorite(uri, on) {
    if (uri.length === 0) {
      return
    }
    if (on) {
      root.send('sticker set song "' + root.esc(uri) + '" favorite 1', null)
    } else {
      root.send('sticker delete song "' + root.esc(uri) + '" favorite', null)
    }
    const next = Object.assign({}, root.favorites)
    if (on) {
      next[uri] = true
    } else {
      delete next[uri]
    }
    root.favorites = next
  }

  function setPinned(uri, on) {
    if (uri.length === 0) {
      return
    }
    if (on) {
      root.send('sticker set song "' + root.esc(uri) + '" pinned 1', null)
    } else {
      root.send('sticker delete song "' + root.esc(uri) + '" pinned', null)
    }
    const next = Object.assign({}, root.pinned)
    if (on) {
      next[uri] = true
    } else {
      delete next[uri]
    }
    root.pinned = next
  }

  function isFavorite(uri) {
    return !!root.favorites[uri]
  }

  function isPinned(uri) {
    return !!root.pinned[uri]
  }

  function resolveCover() {
    if (!root.song) {
      root.coverPath = ""
      return
    }
    const prev = root.artIndex
    root.artIndex = root.artIndex + 1
    const tag = root.artIndex
    if (coverProc.running) {
      coverProc.running = false
    }
    coverProc.tag = tag
    const out = root.cacheDir + "/cover-" + tag + ".img"
    const folder = root.parentDir(root.song.file)
    const base = root.musicDir.endsWith("/") ? root.musicDir.slice(0, -1) : root.musicDir
    let cmd = "mkdir -p '" + root.cacheDir + "' && find '" + root.cacheDir + "' -maxdepth 1 -name 'cover-*.img' ! -name 'cover-" + prev + ".img' -delete && "
    if (base.length > 0) {
      const dir = base + (folder.length > 0 ? "/" + folder : "")
      cmd += "cd '" + dir + "' 2>/dev/null && for n in " + root.coverNames.join(" ") + "; do [ -f \"$n\" ] && cat \"$n\" > '" + out + "' && break; done; "
    }
    cmd += "[ -s '" + out + "' ] || mpc -q readpicture '" + root.esc(root.song.file) + "' > '" + out + "' 2>/dev/null; "
    cmd += "[ -s '" + out + "' ] || mpc -q albumart '" + root.esc(root.song.file) + "' > '" + out + "' 2>/dev/null; "
    cmd += "test -s '" + out + "'"
    coverProc.command = ["sh", "-c", cmd]
    coverProc.running = true
  }

  function trackCover(file) {
    const c = root.trackCovers[file]
    return typeof c === "string" ? c : ""
  }

  function ensureTrackCover(file) {
    if (file.length === 0 || root.trackCovers[file] !== undefined) {
      return
    }
    const next = Object.assign({}, root.trackCovers)
    next[file] = null
    root.trackCovers = next
    root.trackCoverQueue = root.trackCoverQueue.concat([file])
    root.pumpTrackCover()
  }

  function pumpTrackCover() {
    if (trackCoverProc.running || root.trackCoverQueue.length === 0) {
      return
    }
    const file = root.trackCoverQueue[0]
    root.trackCoverQueue = root.trackCoverQueue.slice(1)
    trackCoverProc.tag = file
    const out = root.cacheDir + "/track-" + Qt.md5(file) + ".img"
    trackCoverProc.out = out
    let cmd = "mkdir -p '" + root.cacheDir + "'; "
    cmd += "[ -s '" + out + "' ] || mpc -q readpicture '" + root.esc(file) + "' > '" + out + "' 2>/dev/null; "
    cmd += "[ -s '" + out + "' ] || mpc -q albumart '" + root.esc(file) + "' > '" + out + "' 2>/dev/null; "
    cmd += "test -s '" + out + "'"
    trackCoverProc.command = ["sh", "-c", cmd]
    trackCoverProc.running = true
  }

  function weightedKey(w) {
    const r = Math.random()
    return Math.pow(r, 1.0 / w)
  }

  function weightOf(uri) {
    if (root.pinned[uri]) {
      return 4
    }
    if (root.favorites[uri]) {
      return 2
    }
    return 1
  }

  function reorderRemaining() {
    // collect current queue after current song, reorder by weight
    if (!root.connected || root.queue.length <= 1) {
      return
    }
    const curId = root.song ? root.song.id : -1
    const remaining = root.queue.filter(q => q.id !== curId)
    const scored = remaining.map(q => ({
          q: q,
          key: root.weightedKey(root.weightOf(q.file))
        }))
    scored.sort((a, b) => b.key - a.key)
    // rebuild queue via move? simpler: clear and re-add all keeping current first
    const cur = root.queue.find(q => q.id === curId)
    root.beginClear()
    root.send("clear", null)
    if (cur) {
      root.send("add \"" + root.esc(cur.file) + "\"", null)
    }
    for (let i = 0; i < scored.length; i++) {
      root.send("add \"" + root.esc(scored[i].q.file) + "\"", null)
    }
    root.send("play 0", null)
    root.syncAll()
  }

  function clearAndPlayWeighted(dir) {
    // gather files via lsinfo recursively? MPD add dir handles recursion for play folder.
    // For weighted, we need file list. Use lsinfo on dir (non-recursive) only; spec says including subfolders.
    // Simpler: clear, add dir (mpd recursion), then fetch playlist and reorder.
    root.beginClear()
    root.send("clear", null)
    if (dir === "") {
      root.send("add \"\"", null)
    } else {
      root.send("add \"" + root.esc(dir) + "\"", null)
    }
    root.send("play", null)
    // reorder after load via idle playlist event; handle in syncAll? We'll call reorderRemaining after a delay
    reorderTimer.restart()
  }

  function fmtTime(seconds) {
    const total = Math.max(0, Math.round(seconds))
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    const mm = h > 0 ? String(m).padStart(2, "0") : String(m)
    const ss = String(s).padStart(2, "0")
    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
  }

  function fmtCount(value) {
    const n = Math.max(0, Math.round(value))
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }

  function loadState() {
    stateView.reload()
  }

  function saveState() {
    saveTimer.restart()
  }

  function doSaveState() {
    const obj = {
      playSource: root.playSource,
      weightedRandom: root.weightedRandom,
      lastTab: root.lastTab
    }
    const json = JSON.stringify(obj)
    stateWriter.command = ["sh", "-c", "mkdir -p '" + root.stateFile.substring(0, root.stateFile.lastIndexOf("/")) + "' && printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.stateFile + ".tmp' && mv '" + root.stateFile + ".tmp' '" + root.stateFile + "'"]
    stateWriter.running = true
  }

  Component.onCompleted: {
    // ensure cache dir
    mkdirProc.running = true
  }

  Timer {
    id: tickTimer

    interval: 200
    running: root.connected && root.state === "play"
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      const limit = root.duration
      let next = root.elapsedBase + (Date.now() - root.elapsedAt) / 1000
      if (limit > 0 && next > limit) {
        next = limit
      }
      root.elapsed = next
    }
  }

  Timer {
    id: fadeTimer

    interval: 30
    repeat: true
    onTriggered: {
      const t = Math.min(1, (Date.now() - root.fadeStart) / root.fadeDuration)
      const e = t * t * (3 - 2 * t)
      root.setVolume(root.fadeFrom + (root.fadeTo - root.fadeFrom) * e)
      if (t >= 1) {
        fadeTimer.stop()
        const cb = root.fadeDone
        root.fadeDone = null
        if (cb) {
          cb()
        }
      }
    }
  }

  Timer {
    id: restoreTimer

    interval: 150
    repeat: false
    onTriggered: {
      if (root.restoreVolume < 0 || !root.streamAudio) {
        return
      }
      root.setVolume(root.restoreVolume)
      root.restoreVolume = -1
    }
  }

  Timer {
    id: volumeSettleTimer

    interval: 400
    repeat: false
    onTriggered: {
      if (root.streamAudio) {
        root.lastVolume = Math.min(100, Math.round(root.streamAudio.volume * 100))
      }
    }
  }

  Timer {
    id: streamGraceTimer

    interval: 1000
    repeat: false
  }

  Timer {
    id: retryTimer

    interval: 1000
    running: !root.greeted
    repeat: true
    triggeredOnStart: true
    onTriggered: root.attemptConnect()
  }

  Timer {
    id: reorderTimer

    interval: 800
    repeat: false
    onTriggered: root.reorderRemaining()
  }

  Timer {
    id: saveTimer

    interval: 400
    repeat: false
    onTriggered: root.doSaveState()
  }

  Timer {
    id: clearGuardTimer

    interval: 1500
    repeat: false
    onTriggered: root.clearingQueue = false
  }

  function attemptConnect() {
    root.reset()
    root.sockActive = false
    root.sockActive = true
  }

  property bool sockActive: false

  Loader {
    id: sockLoader

    active: root.sockActive
    sourceComponent: Socket {
      connected: true
      path: root.socketPath
      parser: SplitParser {
        splitMarker: "\n"
        onRead: line => root.onLine(line)
      }

      onConnectionStateChanged: if (!connected) {
        root.reset()
      }

      onError: error => {
        console.warn("mpd socket error:" + error)
      }
    }
  }

  PwObjectTracker {
    objects: root.streamNode ? [root.streamNode] : []
  }

  Process {
    id: coverProc

    property int tag: 0

    running: false
    onExited: (code, status) => {
      if (coverProc.tag !== root.artIndex) {
        return
      }
      root.coverPath = code === 0 ? root.cacheDir + "/cover-" + root.artIndex + ".img" : ""
    }
  }

  Process {
    id: trackCoverProc

    property string tag: ""
    property string out: ""

    running: false
    onExited: (code, status) => {
      const next = Object.assign({}, root.trackCovers)
      next[trackCoverProc.tag] = code === 0 ? trackCoverProc.out : ""
      root.trackCovers = next
      root.pumpTrackCover()
    }
  }

  Process {
    id: mkdirProc

    command: ["sh", "-c", "mkdir -p '" + root.cacheDir + "' '" + root.stateFile.substring(0, root.stateFile.lastIndexOf("/")) + "' && find '" + root.cacheDir + "' -name 'track-*.img' -mtime +60 -delete"]
    running: false
  }

  Process {
    id: stateWriter

    running: false
  }

  FileView {
    id: stateView

    path: root.stateFile
    watchChanges: false
    onLoaded: {
      try {
        const obj = JSON.parse(text())
        root.playSource = obj.playSource || ""
        root.weightedRandom = !!obj.weightedRandom
        root.lastTab = obj.lastTab || 0
      } catch (e) {
        // ignore
      }
    }
    onLoadFailed: error => {
    // ignore missing file
    }
  }
}
