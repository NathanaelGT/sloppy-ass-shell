pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string dbPath: Quickshell.env("HOME") + "/.local/state/quickshell/notifications.db"
  readonly property string sqlite: "sqlite3"
  readonly property int retentionDays: 90
  readonly property int pageSize: 100
  readonly property int initialCount: 200
  readonly property int maxImageBytes: 2 * 1024 * 1024

  property var history: []
  property int unreadCount: 0
  property int lastSeen: 0
  property bool ready: false
  property bool exhausted: false
  property bool loadingMore: false
  property var imageUrls: ({})
  property var avatarKeys: ({})
  property string lastRaw: ""
  property int rawCode: 0
  property int rawSeq: 0

  property var queue: []
  property bool busy: false
  property var current: null
  property bool clearing: false

  function sqlText(s) {
    return "'" + String(s === undefined || s === null ? "" : s).replace(/'/g, "''") + "'"
  }

  function run(argv, onDone) {
    queue.push({
      argv: argv,
      onDone: onDone
    })
    pump()
  }

  function pump() {
    if (busy || queue.length === 0) {
      return
    }
    busy = true
    current = queue.shift()
    dbProc.command = current.argv
    dbProc.running = true
  }

  function settle(code) {
    busy = false
    const job = current
    current = null
    if (job && job.onDone) {
      job.onDone(code, dbOut.text, dbErr.text)
    }
    pump()
  }

  function parseActions(s) {
    if (!s || s.length === 0) {
      return []
    }
    try {
      const a = JSON.parse(s)
      return Array.isArray(a) ? a : []
    } catch (e) {
      return []
    }
  }

  function dayLabel(ts) {
    const d = new Date(ts * 1000)
    const now = new Date()
    const startOfDay = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
    const diff = Math.round((startOfDay(now) - startOfDay(d)) / 86400000)
    if (diff <= 0) {
      return "Today"
    }
    if (diff === 1) {
      return "Yesterday"
    }
    return Qt.formatDate(d, "dddd, d MMMM")
  }

  function recomputeDays() {
    const labels = []
    for (let i = 0; i < root.history.length; i++) {
      labels.push(dayLabel(root.history[i].ts))
    }
    const out = []
    for (let i = 0; i < root.history.length; i++) {
      const e = root.history[i]
      out.push({
        id: e.id,
        ts: e.ts,
        appName: e.appName,
        appIcon: e.appIcon,
        desktopEntry: e.desktopEntry,
        summary: e.summary,
        body: e.body,
        urgency: e.urgency,
        actions: e.actions,
        transient: e.transient,
        imageKind: e.imageKind,
        hasImage: e.hasImage,
        day: labels[i],
        firstInDay: i === 0 || labels[i] !== labels[i - 1],
        lastInDay: i === labels.length - 1 || labels[i] !== labels[i + 1]
      })
    }
    root.history = out
  }

  function open() {
    const cutoff = "strftime('%s','now') - " + retentionDays * 86400
    const init = "PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, app_name TEXT, app_icon TEXT, desktop_entry TEXT, summary TEXT, body TEXT, urgency INTEGER DEFAULT 1, actions TEXT, transient INTEGER DEFAULT 0, deleted_at INTEGER, image BLOB); CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT); CREATE TABLE IF NOT EXISTS avatars (key TEXT PRIMARY KEY, image BLOB NOT NULL, updated_at INTEGER NOT NULL); DELETE FROM notifications WHERE ts < " + cutoff + "; DELETE FROM avatars WHERE key NOT IN (SELECT app_name || char(31) || summary FROM notifications WHERE deleted_at IS NULL AND app_name IS NOT NULL AND summary IS NOT NULL);"
    run([sqlite, dbPath, init], code => {
      run([sqlite, "-json", dbPath, "SELECT key FROM avatars"], (c0, out0) => {
        const keys = {}
        if (c0 === 0 && out0.trim().length > 0) {
          try {
            const rows = JSON.parse(out0)
            for (let i = 0; i < rows.length; i++) {
              if (rows[i].key) {
                keys[rows[i].key] = true
              }
            }
          } catch (e) {}
        }
        root.avatarKeys = keys
        run([sqlite, "-json", dbPath, "SELECT value FROM meta WHERE key='lastSeen'"], (c, out) => {
          let seen = 0
          if (c === 0 && out.trim().length > 0) {
            try {
              const rows = JSON.parse(out)
              if (rows.length > 0) {
                seen = parseInt(rows[0].value) || 0
              }
            } catch (e) {}
          }
          root.lastSeen = seen
          run([sqlite, "-json", dbPath, "SELECT COUNT(*) AS n FROM notifications WHERE deleted_at IS NULL AND ts > " + seen], (c2, out2) => {
            if (c2 === 0 && out2.trim().length > 0) {
              try {
                root.unreadCount = JSON.parse(out2)[0].n || 0
              } catch (e) {}
            }
            fetchPage(initialCount, true)
          })
        })
      })
    })
  }

  function fetchPage(limit, initial, onDone) {
    const cols = "n.id,n.ts,n.app_name,n.app_icon,n.desktop_entry,n.summary,n.body,n.urgency,n.actions,n.transient,CASE WHEN a.image IS NOT NULL THEN 'avatar' WHEN n.image IS NOT NULL THEN 'image' ELSE '' END AS image_kind"
    run([sqlite, "-json", dbPath, "SELECT " + cols + " FROM notifications n LEFT JOIN avatars a ON a.key = n.app_name || char(31) || n.summary WHERE n.deleted_at IS NULL ORDER BY n.ts DESC, n.id DESC LIMIT " + limit + " OFFSET " + root.history.length], (code, out) => {
      let rows = []
      if (code === 0 && out.trim().length > 0) {
        try {
          rows = JSON.parse(out)
        } catch (e) {
          rows = []
        }
      }
      const have = {}
      for (let i = 0; i < root.history.length; i++) {
        have[root.history[i].id] = true
      }
      const page = []
      for (let i = 0; i < rows.length; i++) {
        const r = rows[i]
        if (have[r.id]) {
          continue
        }
        page.push({
          id: r.id,
          ts: r.ts,
          appName: r.app_name || "",
          appIcon: r.app_icon || "",
          desktopEntry: r.desktop_entry || "",
          summary: r.summary || "",
          body: r.body || "",
          urgency: r.urgency,
          actions: parseActions(r.actions),
          transient: r.transient === 1,
          imageKind: r.image_kind || "",
          hasImage: (r.image_kind || "") !== ""
        })
      }
      root.history = initial ? page : root.history.concat(page)
      if (rows.length < limit) {
        exhausted = true
      }
      recomputeDays()
      if (initial) {
        ready = true
      }
      loadingMore = false
      if (onDone) {
        onDone()
      }
    })
  }

  function loadMore() {
    if (loadingMore || exhausted || !ready) {
      return
    }
    loadingMore = true
    fetchPage(pageSize, false)
  }

  function record(entry) {
    const key = entry.avatarKey || ""
    const avatarTmp = entry.avatarTmp || ""

    const insertNotification = () => {
      const avatarReady = key !== "" && root.avatarKeys[key] === true
      const img = avatarReady || !entry.imageTmp ? "NULL" : "readfile(" + sqlText(entry.imageTmp) + ")"
      const delCol = root.clearing ? ",deleted_at" : ""
      const delVal = root.clearing ? ",strftime('%s','now')" : ""
      const sql = "INSERT INTO notifications (ts,app_name,app_icon,desktop_entry,summary,body,urgency,actions,transient,image" + delCol + ") VALUES (" + Math.round(entry.ts) + "," + sqlText(entry.appName) + "," + sqlText(entry.appIcon) + "," + sqlText(entry.desktopEntry) + "," + sqlText(entry.summary) + "," + sqlText(entry.body) + "," + Math.round(entry.urgency === undefined ? 1 : entry.urgency) + "," + sqlText(JSON.stringify(entry.actions || [])) + "," + (entry.transient ? 1 : 0) + "," + img + delVal + ") RETURNING id"
      run([sqlite, "-json", dbPath, sql], (code, out) => {
        let id = 0
        if (code === 0 && out.trim().length > 0) {
          try {
            id = JSON.parse(out)[0].id
          } catch (e) {}
        }
        if (root.clearing) {
          return
        }
        root.history = [
          {
            id: id,
            ts: entry.ts,
            appName: entry.appName || "",
            appIcon: entry.appIcon || "",
            desktopEntry: entry.desktopEntry || "",
            summary: entry.summary || "",
            body: entry.body || "",
            urgency: entry.urgency === undefined ? 1 : entry.urgency,
            actions: entry.actions || [],
            transient: entry.transient === true,
            imageKind: avatarReady ? "avatar" : (entry.imageTmp ? "image" : ""),
            hasImage: avatarReady || (entry.imageTmp !== "" && entry.imageTmp !== undefined)
          }
        ].concat(root.history)
        recomputeDays()
      })
    }

    if (key !== "" && avatarTmp !== "" && root.avatarKeys[key] !== true) {
      const avatarSql = "INSERT INTO avatars (key,image,updated_at) SELECT " + sqlText(key) + ",readfile(" + sqlText(avatarTmp) + ")," + Math.floor(Date.now() / 1000) + " WHERE NOT EXISTS (SELECT 1 FROM avatars WHERE key=" + sqlText(key) + ")"
      run([sqlite, dbPath, avatarSql], code => {
        if (code === 0) {
          const upd = Object.assign({}, root.avatarKeys)
          upd[key] = true
          root.avatarKeys = upd
        }
        insertNotification()
      })
    } else {
      insertNotification()
    }
  }

  function removeEntry(id) {
    run([sqlite, dbPath, "UPDATE notifications SET deleted_at=strftime('%s','now') WHERE id=" + id])
    const gone = root.history.find(x => x.id === id)
    root.history = root.history.filter(x => x.id !== id)
    recomputeDays()
    if (gone && gone.ts > root.lastSeen && root.unreadCount > 0) {
      root.unreadCount -= 1
    }
  }

  function clearHistory() {
    root.clearing = true
    run([sqlite, dbPath, "UPDATE notifications SET deleted_at=strftime('%s','now') WHERE deleted_at IS NULL"])
    root.history = []
    exhausted = true
    root.unreadCount = 0
    markSeen()
    clearFlagTimer.restart()
  }

  function undoClear(fromTs, toTs, onDone) {
    run([sqlite, dbPath, "UPDATE notifications SET deleted_at=NULL WHERE deleted_at IS NOT NULL AND deleted_at >= " + Math.round(fromTs) + " AND deleted_at <= " + Math.round(toTs)], () => {
      root.history = []
      exhausted = false
      fetchPage(initialCount, true, onDone)
      run([sqlite, "-json", dbPath, "SELECT COUNT(*) AS n FROM notifications WHERE deleted_at IS NULL AND ts > " + root.lastSeen], (c2, out2) => {
        if (c2 === 0 && out2.trim().length > 0) {
          try {
            root.unreadCount = JSON.parse(out2)[0].n || 0
          } catch (e) {}
        }
      })
    })
  }

  function setLastSeenNow() {
    root.lastSeen = Math.floor(Date.now() / 1000)
    run([sqlite, dbPath, "INSERT OR REPLACE INTO meta (key,value) VALUES ('lastSeen'," + root.lastSeen + ")"])
  }

  function markSeen() {
    root.unreadCount = 0
    setLastSeenNow()
  }

  function noteArrival() {
    root.unreadCount += 1
  }

  function chatKeyOf(entry) {
    if (!entry.appName || !entry.summary) {
      return ""
    }
    return entry.appName + "\u001f" + entry.summary
  }

  function avatarPathFor(entry) {
    return "/tmp/quickshell-notif-img/avatar-" + keyHash(chatKeyOf(entry)) + ".png"
  }

  function keyHash(s) {
    let h = 2166136261
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i)
      h = Math.imul(h, 16777619)
    }
    return (h >>> 0).toString(16)
  }

  function historyEntry(id) {
    for (let i = 0; i < root.history.length; i++) {
      if (root.history[i].id === id) {
        return root.history[i]
      }
    }
    return null
  }

  function hasAvatar(key) {
    return key !== "" && root.avatarKeys[key] === true
  }

  function requestImage(id) {
    if (imageUrls[id] !== undefined) {
      return
    }
    const entry = historyEntry(id)
    if (!entry || entry.imageKind === "") {
      return
    }
    const reserved = Object.assign({}, imageUrls)
    reserved[id] = ""
    imageUrls = reserved
    const avatar = entry.imageKind === "avatar"
    const dst = avatar ? avatarPathFor(entry) : "/tmp/quickshell-notif-img/hist-" + id + ".png"
    const sql = avatar ? "SELECT writefile(" + sqlText(dst) + ", image) AS n FROM avatars WHERE key=" + sqlText(chatKeyOf(entry)) : "SELECT writefile(" + sqlText(dst) + ", image) AS n FROM notifications WHERE id=" + id + " AND image IS NOT NULL"
    run([sqlite, "-json", dbPath, sql], (code, out) => {
      let ok = false
      if (code === 0 && out.trim().length > 0) {
        try {
          ok = (JSON.parse(out)[0].n || 0) > 0
        } catch (e) {}
      }
      const upd = Object.assign({}, root.imageUrls)
      upd[id] = ok ? "file://" + dst : ""
      root.imageUrls = upd
    })
  }

  function imageUrlFor(id) {
    return imageUrls[id] === undefined ? "" : imageUrls[id]
  }

  function runRaw(sql) {
    run([sqlite, "-json", dbPath, sql], (code, out) => {
      rawCode = code
      root.lastRaw = out
      rawSeq += 1
    })
  }

  Component.onCompleted: open()

  Timer {
    id: clearFlagTimer

    interval: 500
    onTriggered: root.clearing = false
  }

  Process {
    id: dbProc

    stdout: StdioCollector {
      id: dbOut
    }
    stderr: StdioCollector {
      id: dbErr
    }
    onExited: code => root.settle(code)
  }
}
