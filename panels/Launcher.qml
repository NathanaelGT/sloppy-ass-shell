import QtQuick
import Quickshell
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "launcher"
  align: "center"
  topMargin: Math.round((modelData ? modelData.height : 0) * 0.16)
  cardWidth: Theme.panelWidth
  maxCardHeight: Math.min(Math.round((modelData ? modelData.height : 0) * 0.7), root.contentPad * 2 + root.headerHeight + Theme.gap + root.listCap)
  exclusiveFocus: true
  autoFocusKeyCatcher: false
  animateCardHeight: true

  property string query: ""
  property int selectedIndex: 0
  property var shownEntries: []
  property int prevCount: 0
  property bool xfadeActive: false
  property string xfadeDir: ""
  property bool xfadeHold: false

  readonly property int rowHeight: Math.round(48 * Theme.scale)
  readonly property int subtitleSize: Math.round(9 * Theme.scale)
  readonly property int maxVisibleRows: 8
  readonly property int iconInset: Math.round(12 * Theme.scale)
  readonly property int iconSlotSize: Math.round(24 * Theme.scale)
  readonly property int textGap: Math.round(12 * Theme.scale)
  readonly property int starSize: Math.round(24 * Theme.scale)
  readonly property int headerHeight: searchRow.height + Theme.gap + 1
  readonly property int listCap: root.maxVisibleRows * root.rowHeight + (root.maxVisibleRows - 1) * Theme.gap
  readonly property int rowTextRight: root.iconInset + root.starSize

  readonly property var fieldWeights: ({
      name: 40,
      keywords: 25,
      genericName: 20,
      comment: 15
    })

  readonly property var installedApps: {
    const model = DesktopEntries.applications
    const all = model ? model.values : []
    const out = []
    for (let i = 0; i < all.length; i++) {
      if (!all[i].noDisplay) {
        out.push(all[i])
      }
    }
    return out
  }

  readonly property var queryTokens: {
    const q = root.query.trim().toLowerCase()
    return q.length === 0 ? [] : q.split(/\s+/).filter(function (token) {
      return token.length > 0
    })
  }

  readonly property var availableImages: {
    const out = []
    const images = AppImages.available
    for (let i = 0; i < images.length; i++) {
      let clash = false
      for (let j = 0; j < root.installedApps.length; j++) {
        const name = root.installedApps[j].name ? root.installedApps[j].name.toLowerCase() : ""
        if (name === images[i].name.toLowerCase()) {
          clash = true
          break
        }
      }
      if (!clash) {
        out.push(images[i])
      }
    }
    return out
  }

  readonly property var results: {
    const tokens = root.queryTokens
    const out = []
    const apps = root.installedApps
    for (let i = 0; i < apps.length; i++) {
      const scored = root.scoreFields(tokens, root.appFields(apps[i]))
      if (scored) {
        out.push({
          kind: "app",
          itemKey: "app:" + String(apps[i].id),
          label: apps[i].name ? apps[i].name : "",
          score: scored.score,
          field: scored.field
        })
      }
    }
    const images = root.availableImages
    for (let i = 0; i < images.length; i++) {
      const scored = root.scoreFields(tokens, root.imageFields(images[i]))
      if (scored) {
        out.push({
          kind: "appimage",
          itemKey: "image:" + images[i].path,
          label: images[i].name,
          score: scored.score,
          field: scored.field
        })
      }
    }
    out.sort(function (a, b) {
      const favorite = Favorites.has(a.itemKey) ? 1 : 0
      const other = Favorites.has(b.itemKey) ? 1 : 0
      if (favorite !== other) {
        return other - favorite
      }
      if (b.score !== a.score) {
        return b.score - a.score
      }
      return a.label.localeCompare(b.label)
    })
    return out.slice(0, 150)
  }

  readonly property var calc: evaluate(query)
  readonly property bool commandMode: query.trim().indexOf("$") === 0
  readonly property string commandText: commandMode ? query.trim().slice(1).trim() : ""
  readonly property int rowCount: commandMode ? (commandText.length > 0 ? 1 : 0) : results.length + (calc ? 1 : 0)
  readonly property int selected: rowCount === 0 ? -1 : Math.max(0, Math.min(selectedIndex, rowCount - 1))

  readonly property var entries: {
    const out = []
    if (commandMode) {
      if (commandText.length > 0) {
        out.push({
          kind: "command",
          section: "",
          label: "",
          itemKey: "command",
          active: selected === 0
        })
      }
      return out
    }
    if (calc) {
      out.push({
        kind: "calc",
        section: "",
        label: "",
        itemKey: "calc",
        active: selected === 0
      })
    }
    for (let i = 0; i < results.length; i++) {
      out.push({
        kind: results[i].kind,
        section: "",
        label: "",
        itemKey: results[i].itemKey,
        active: selected === out.length
      })
    }
    return out
  }

  function formatNumber(v) {
    return String(Number(v.toPrecision(12)))
  }

  function formatDisplay(v) {
    const raw = formatNumber(v)
    const negative = raw.charAt(0) === "-";
    const digits = negative ? raw.slice(1) : raw
    const dot = digits.indexOf(".")
    const head = dot < 0 ? digits : digits.slice(0, dot)
    const tail = dot < 0 ? "" : digits.slice(dot + 1)
    if (!/^\d+$/.test(head) || (tail.length > 0 && !/^\d+$/.test(tail))) {
      return raw
    }
    let grouped = ""
    for (let i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 3 === 0) {
        grouped += "."
      }
      grouped += head.charAt(i)
    }
    return (negative ? "-" : "") + grouped + (tail.length > 0 ? "," + tail : "")
  }

  function errorHex() {
    function channel(v) {
      return Math.round(v * 255).toString(16).padStart(2, "0")
    }
    return "#" + channel(Theme.red.r) + channel(Theme.red.g) + channel(Theme.red.b)
  }

  function calcExpression() {
    const c = root.calc
    if (!c) {
      return ""
    }
    if (!c.error || c.error.end <= c.error.start) {
      return c.expression
    }
    const bad = c.expression.slice(c.error.start, c.error.end)
    return c.expression.slice(0, c.error.start) + "<font color=\"" + root.errorHex() + "\">" + bad + "</font>" + c.expression.slice(c.error.end)
  }

  function balanceParens(text) {
    let opens = 0
    let closes = 0
    for (let i = 0; i < text.length; i++) {
      const c = text.charAt(i)
      if (c === "(") {
        opens += 1
      } else if (c === ")") {
        closes += 1
      }
    }
    if (closes > opens) {
      return "(".repeat(closes - opens) + text
    }
    if (opens > closes) {
      return text + ")".repeat(opens - closes)
    }
    return text
  }

  function insertProducts(text) {
    const out = []
    for (let i = 0; i < text.length; i++) {
      const c = text.charAt(i)
      if (i > 0) {
        const prev = text.charAt(i - 1)
        let insert = false
        if (prev === ")") {
          insert = c === "(" || /[0-9.]/.test(c)
        } else if (/[0-9.]/.test(prev) && c === "(") {
          insert = true
        }
        if (insert) {
          out.push("*")
        }
      }
      out.push(c)
    }
    return out.join("")
  }

  function evaluate(input) {
    const raw = (input === undefined || input === null ? "" : String(input)).trim()
    if (/^[+-]?(\d+(\.\d*)?|\.\d+)$/.test(raw) || raw.length === 0 || !/^[0-9.+\-*/^%()\s]*$/.test(raw)) {
      return null
    }
    const expression = insertProducts(balanceParens(raw))
    let pos = 0

    function skip() {
      while (pos < expression.length && /\s/.test(expression.charAt(pos))) {
        pos += 1
      }
    }

    function peek() {
      skip()
      return pos < expression.length ? expression.charAt(pos) : ""
    }

    function isPrimaryStart(c) {
      return /[0-9.]/.test(c) || c === "("
    }

    function parseNumber() {
      skip()
      const start = pos
      while (pos < expression.length && /[0-9.]/.test(expression.charAt(pos))) {
        pos += 1
      }
      if (pos === start) {
        throw new Error("number")
      }
      const value = Number(expression.slice(start, pos))
      if (!isFinite(value)) {
        throw new Error("number")
      }
      return value
    }

    function parsePrimary() {
      skip()
      if (expression.charAt(pos) === "(") {
        pos += 1
        const value = parseExpression()
        skip()
        if (expression.charAt(pos) !== ")") {
          throw new Error("paren")
        }
        pos += 1
        return value
      }
      return parseNumber()
    }

    function parsePostfix() {
      let value = parsePrimary()
      while (peek() === "%") {
        let j = pos + 1
        while (j < expression.length && /\s/.test(expression.charAt(j))) {
          j += 1
        }
        const next = j < expression.length ? expression.charAt(j) : ""
        if (isPrimaryStart(next)) {
          break
        }
        pos += 1
        value = value / 100
      }
      return value
    }

    function parsePower() {
      const base = parsePostfix()
      if (peek() === "^") {
        pos += 1
        return Math.pow(base, parseUnary())
      }
      return base
    }

    function parseUnary() {
      const c = peek()
      if (c === "+") {
        pos += 1
        return parseUnary()
      }
      if (c === "-") {
        pos += 1
        return -parseUnary()
      }
      return parsePower()
    }

    function parseTerm() {
      let value = parseUnary()
      for (; ; ) {
        const c = peek()
        if (c !== "*" && c !== "/" && c !== "%") {
          break
        }
        pos += 1
        const rhs = parseUnary()
        if (c === "*") {
          value = value * rhs
        } else if (c === "/") {
          value = value / rhs
        } else {
          value = value % rhs
        }
      }
      return value
    }

    function parseExpression() {
      let value = parseTerm()
      for (; ; ) {
        const c = peek()
        if (c !== "+" && c !== "-") {
          break
        }
        pos += 1
        const rhs = parseTerm()
        value = c === "+" ? value + rhs : value - rhs
      }
      return value
    }

    try {
      const value = parseExpression()
      skip()
      if (pos !== expression.length) {
        throw new Error("trailing")
      }
      if (!isFinite(value)) {
        return null
      }
      return {
        value: value,
        expression: expression,
        error: null
      }
    } catch (error) {
      const at = Math.max(0, Math.min(pos, expression.length - 1))
      return {
        value: null,
        expression: expression,
        error: {
          start: at,
          end: at + 1
        }
      }
    }
  }

  function keywordsOf(app) {
    const raw = app.keywords
    if (typeof raw === "string") {
      return raw
    }
    if (raw && typeof raw.length === "number") {
      const parts = []
      for (let k = 0; k < raw.length; k++) {
        parts.push(String(raw[k]))
      }
      return parts.join(" ")
    }
    return raw ? String(raw) : ""
  }

  function appFields(app) {
    return {
      name: app.name ? app.name : "",
      keywords: keywordsOf(app),
      genericName: app.genericName ? app.genericName : "",
      comment: app.comment ? app.comment : ""
    }
  }

  function imageFields(image) {
    return {
      name: image.name,
      keywords: image.raw.replace(/[-_.]+/g, " "),
      genericName: "",
      comment: image.dir.replace(/[^a-zA-Z0-9]+/g, " ")
    }
  }

  function appForKey(itemKey) {
    const text = String(itemKey)
    const id = text.indexOf("app:") === 0 ? text.slice(4) : ""
    for (let i = 0; i < installedApps.length; i++) {
      if (String(installedApps[i].id) === id) {
        return installedApps[i]
      }
    }
    return null
  }

  function appImagePathFor(app) {
    if (!app) {
      return ""
    }
    const raw = app.execString ? String(app.execString) : ""
    const match = raw.match(/[^\s"']+\.appimage/i)
    if (match) {
      return match[0]
    }
    const parts = app.command
    if (parts && typeof parts.length === "number") {
      for (let i = 0; i < parts.length; i++) {
        const part = String(parts[i])
        if (/\.appimage$/i.test(part)) {
          return part
        }
      }
    }
    return ""
  }

  function versionForItem(itemKey) {
    const path = root.appImagePathFor(root.appForKey(itemKey))
    return path.length > 0 ? AppImages.versionFor(path) : ""
  }

  function imageForKey(itemKey) {
    const text = String(itemKey)
    const path = text.indexOf("image:") === 0 ? text.slice(6) : ""
    for (let i = 0; i < availableImages.length; i++) {
      if (availableImages[i].path === path) {
        return availableImages[i]
      }
    }
    return null
  }

  function editDistance(a, b, limit) {
    if (Math.abs(a.length - b.length) > limit) {
      return limit + 1
    }
    let previous = []
    for (let j = 0; j <= b.length; j++) {
      previous.push(j)
    }
    for (let i = 1; i <= a.length; i++) {
      const current = [i]
      let rowMin = i
      for (let j = 1; j <= b.length; j++) {
        const cost = a.charAt(i - 1) === b.charAt(j - 1) ? 0 : 1
        const value = Math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        current.push(value)
        if (value < rowMin) {
          rowMin = value
        }
      }
      if (rowMin > limit) {
        return limit + 1
      }
      previous = current
    }
    return previous[b.length]
  }

  function isSubsequence(token, word) {
    let at = 0
    for (let i = 0; i < word.length && at < token.length; i++) {
      if (word.charAt(i) === token.charAt(at)) {
        at += 1
      }
    }
    return at === token.length
  }

  function fieldMatchScore(token, field) {
    const text = String(field).toLowerCase()
    if (text.length === 0) {
      return 0
    }
    const words = text.split(/[^a-z0-9]+/).filter(function (word) {
      return word.length > 0
    })
    for (let i = 0; i < words.length; i++) {
      if (words[i] === token) {
        return 1
      }
    }
    if (text.indexOf(token) >= 0) {
      return 0.85
    }
    let best = 0
    for (let i = 0; i < words.length; i++) {
      const word = words[i]
      const limit = word.length <= 4 ? 1 : 2
      const distance = editDistance(token, word, limit)
      if (distance <= limit) {
        const score = 0.7 - 0.1 * distance
        if (score > best) {
          best = score
        }
      }
    }
    if (best > 0) {
      return best
    }
    for (let i = 0; i < words.length; i++) {
      if (words[i].length > 0 && isSubsequence(token, words[i])) {
        const score = 0.4 * (token.length / words[i].length)
        if (score > best) {
          best = score
        }
      }
    }
    return best
  }

  function scoreFields(tokens, fields) {
    const keys = ["name", "keywords", "genericName", "comment"]
    if (tokens.length === 0) {
      return {
        score: 0,
        field: "none"
      }
    }
    const sums = {
      name: 0,
      keywords: 0,
      genericName: 0,
      comment: 0
    }
    for (let t = 0; t < tokens.length; t++) {
      let tokenBest = 0
      for (let k = 0; k < keys.length; k++) {
        const value = fieldMatchScore(tokens[t], fields[keys[k]])
        if (value > tokenBest) {
          tokenBest = value
        }
        sums[keys[k]] += value
      }
      if (tokenBest <= 0) {
        return null
      }
    }
    let total = 0
    let bestField = "name"
    let bestWeighted = -1
    for (let k = 0; k < keys.length; k++) {
      const weighted = fieldWeights[keys[k]] * (sums[keys[k]] / tokens.length)
      total += weighted
      if (weighted > bestWeighted) {
        bestWeighted = weighted
        bestField = keys[k]
      }
    }
    return {
      score: total,
      field: bestField
    }
  }

  function rowTop(index) {
    return index * (root.rowHeight + Theme.gap)
  }

  function isFavoritableKey(itemKey) {
    const text = String(itemKey)
    return text.indexOf("app:") === 0 || text.indexOf("image:") === 0
  }

  function indexOfKey(key) {
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].itemKey === key) {
        return i
      }
    }
    return -1
  }

  function toggleFavoriteItem(itemKey) {
    const key = String(itemKey)
    Favorites.toggle(key)
    Qt.callLater(function () {
      const index = root.indexOfKey(key)
      if (index >= 0) {
        root.selectedIndex = index
      }
    })
  }

  function favoriteSelected() {
    const entry = entries[root.selected]
    if (!entry || !root.isFavoritableKey(entry.itemKey)) {
      return false
    }
    root.toggleFavoriteItem(entry.itemKey)
    return true
  }

  function moveSelection(delta) {
    root.selectedIndex = Math.max(0, Math.min(rowCount - 1, root.selected + delta))
  }

  function firstVisibleIndex() {
    const stride = root.rowHeight + Theme.gap
    if (stride <= 0 || rowCount <= 0) {
      return 0
    }
    const top = Math.max(0, root.scrollY - list.y)
    return Math.max(0, Math.min(rowCount - 1, Math.floor(top / stride)))
  }

  function visibleIndexFor(offset) {
    const index = root.firstVisibleIndex() + offset
    if (index < 0 || index >= rowCount) {
      return -1
    }
    return index
  }

  function activateVisible(offset) {
    const index = root.visibleIndexFor(offset)
    if (index < 0) {
      return false
    }
    return root.activateIndex(index)
  }

  function kittyArgv(command) {
    return ["kitty", "--hold", "-d", Quickshell.env("HOME"), "--class", "command-runner", "-o", "confirm_os_window_close=0", "-e", "bash", "-lc", command]
  }

  function activateIndex(index) {
    const entry = entries[index]
    if (!entry) {
      return false
    }
    if (entry.kind === "calc") {
      if (!calc || calc.value === null) {
        return false
      }
      Quickshell.clipboardText = formatNumber(calc.value)
    } else if (entry.kind === "command") {
      if (commandText.length === 0) {
        return false
      }
      Quickshell.execDetached(kittyArgv(commandText))
    } else if (entry.kind === "app") {
      const app = appForKey(entry.itemKey)
      if (!app) {
        return false
      }
      app.execute()
    } else if (entry.kind === "appimage") {
      const image = imageForKey(entry.itemKey)
      if (!image) {
        return false
      }
      Quickshell.execDetached(["appimage-run", image.path])
    } else {
      return false
    }
    Panels.close()
    return true
  }

  function testSetQuery(text) {
    root.query = text
    return true
  }

  function testSelect(index) {
    root.selectedIndex = index
    return true
  }

  function testState() {
    const rows = []
    const scored = {}
    for (let s = 0; s < root.results.length; s++) {
      scored[root.results[s].itemKey] = root.results[s]
    }
    for (let i = 0; i < root.entries.length; i++) {
      const entry = root.entries[i]
      let name = ""
      let detail = ""
      let icon = ""
      if (entry.kind === "calc") {
        name = root.calc && root.calc.value !== null ? root.formatDisplay(root.calc.value) : ""
        detail = root.calc ? root.calc.expression : ""
      } else if (entry.kind === "command") {
        name = root.commandText
      } else if (entry.kind === "appimage") {
        const image = root.imageForKey(entry.itemKey)
        const metaName = image ? AppImages.nameFor(image.path) : ""
        const metaVersion = image ? AppImages.versionFor(image.path) : ""
        name = metaName.length > 0 ? metaName : (image ? image.name : entry.itemKey)
        detail = metaVersion.length > 0 ? metaVersion : (image ? image.detail : "")
        icon = image ? AppImages.iconFor(image.path) : ""
      } else {
        const app = root.appForKey(entry.itemKey)
        name = app && app.name ? app.name : entry.itemKey
        detail = root.versionForItem(entry.itemKey)
      }
      const match = scored[entry.itemKey]
      rows.push({
        kind: entry.kind,
        name: name,
        detail: detail,
        icon: icon,
        error: entry.kind === "calc" && root.calc ? root.calc.error : null,
        score: match ? Math.round(match.score * 100) / 100 : 0,
        field: match ? match.field : "",
        favorite: root.isFavoritableKey(entry.itemKey) ? Favorites.has(entry.itemKey) : false,
        selected: i === root.selected
      })
    }
    return {
      query: root.query,
      text: searchInput.text,
      selected: root.selected,
      rows: rows,
      layout: root.testLayout()
    }
  }

  function testFavorite() {
    return root.favoriteSelected()
  }

  function testVisibleTarget(offset) {
    return root.visibleIndexFor(offset)
  }

  function testLayout() {
    const listOrigin = list.mapToItem(null, 0, 0)
    const iconOrigin = searchIconSlot.mapToItem(null, 0, 0)
    const textOrigin = searchInput.mapToItem(null, 0, 0)
    return {
      rowHeight: root.rowHeight,
      headerHeight: root.headerHeight,
      cardHeight: root.cardHeight,
      viewportHeight: root.viewportHeight,
      scrollY: root.scrollY,
      listY: list.y,
      searchIconX: iconOrigin ? iconOrigin.x + searchIconSlot.width / 2 : -1,
      rowIconX: listOrigin ? listOrigin.x + root.iconInset + root.iconSlotSize / 2 : -1,
      searchTextX: textOrigin ? textOrigin.x : -1,
      rowTextX: listOrigin ? listOrigin.x + root.iconInset + root.iconSlotSize + root.textGap : -1,
      morphMode: morphCard.mode,
      morphVisible: morphCard.visible,
      morphHeight: morphCard.height,
      morphOpacity: morphCard.opacity,
      emptyOpacity: emptyContent.opacity,
      commandOpacity: commandContent.opacity,
      listVisible: list.visible,
      xfadeActive: root.xfadeActive,
      xfadeDir: root.xfadeDir,
      shownCount: root.shownEntries.length,
      firstVisible: root.firstVisibleIndex()
    }
  }

  function testEval(expression) {
    const result = evaluate(expression)
    if (!result) {
      return {
        ok: false,
        value: "",
        expression: "",
        error: null
      }
    }
    return {
      ok: result.value !== null,
      value: result.value !== null ? formatDisplay(result.value) : "",
      expression: result.expression,
      error: result.error
    }
  }

  function testKittyArgv(command) {
    return kittyArgv(command)
  }

  function testDebug() {
    return list.testDebug()
  }

  function testActivate() {
    if (root.selected < 0) {
      return false
    }
    return root.activateIndex(root.selected)
  }

  function snapMorphHeight() {
    if (!morphCard.visible) {
      return
    }
    morphHeightBehavior.enabled = false
    morphHeightAnim.stop()
    morphCard.height = Qt.binding(function () {
      return morphCard.mode === "empty" ? morphCard.emptyHeight : root.rowHeight
    })
    morphHeightBehavior.enabled = true
  }

  function startXfade(dir) {
    root.xfadeActive = true
    root.xfadeDir = dir
    if (dir === "out") {
      root.shownEntries = root.entries.slice()
      root.xfadeHold = true
    } else {
      morphCard.opacity = 0
    }
    xfadeAnim.to = dir === "in" ? 1 : 0
    xfadeAnim.restart()
    xfadeTimer.restart()
  }

  function finishXfade() {
    xfadeTimer.stop()
    if (root.xfadeDir === "in") {
      root.shownEntries = root.entries.slice()
    } else {
      root.xfadeHold = false
    }
    root.xfadeActive = false
    root.xfadeDir = ""
    morphCard.opacity = 1
  }

  function abortXfade() {
    xfadeTimer.stop()
    xfadeAnim.stop()
    root.xfadeActive = false
    root.xfadeDir = ""
    root.xfadeHold = false
    morphCard.opacity = 1
  }

  function handleEntriesChanged() {
    const n = root.entries.length
    const p = root.prevCount
    if (root.xfadeActive) {
      root.abortXfade()
    }
    if (n === 0 && p === 2) {
      root.startXfade("in")
    } else if (p === 0 && n === 2) {
      root.startXfade("out")
    } else {
      root.shownEntries = root.entries.slice()
    }
    root.prevCount = n
  }

  Timer {
    id: xfadeTimer

    interval: 160
    onTriggered: root.finishXfade()
  }

  NumberAnimation {
    id: xfadeAnim

    target: morphCard
    property: "opacity"
    duration: 160
    easing.type: Easing.OutCubic
  }

  onEntriesChanged: root.handleEntriesChanged()

  Component.onCompleted: {
    root.shownEntries = root.entries.slice()
    root.prevCount = root.entries.length
  }

  onQueryChanged: selectedIndex = 0

  onSelectedChanged: if (selected >= 0) {
    ensureVisible(list.y + rowTop(selected), root.rowHeight, 0)
  }

  onOpened: {
    root.abortXfade()
    root.shownEntries = root.entries.slice()
    root.prevCount = root.entries.length
    root.query = ""
    searchInput.text = root.query
    selectedIndex = 0
    scrollToTop()
    searchInput.forceActiveFocus()
  }

  headerData: Column {
    id: searchHeader

    width: parent.width
    spacing: Theme.gap

    Item {
      id: searchRow

      width: parent.width
      height: Math.max(root.iconSlotSize, searchInput.implicitHeight)

      Item {
        id: searchIconSlot

        anchors.left: parent.left
        anchors.leftMargin: root.iconInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSlotSize
        height: width

        Icon {
          anchors.centerIn: parent
          name: "search"
          font.pixelSize: Theme.iconSizeLarge
        }
      }

      TextInput {
        id: searchInput

        anchors.left: searchIconSlot.right
        anchors.leftMargin: root.textGap
        anchors.right: parent.right
        anchors.rightMargin: root.iconInset
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.onAccent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        focus: true
        clip: true
        onTextChanged: root.query = text
        onAccepted: if (root.selected >= 0) {
          root.activateIndex(root.selected)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: searchInput.text.length === 0
          text: "Search applications"
          color: Theme.overlay
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLarge
        }

        Keys.onUpPressed: root.moveSelection(-1)
        Keys.onDownPressed: root.moveSelection(1)
        Keys.onPressed: event => {
          if (event.key === Qt.Key_PageUp) {
            root.moveSelection(-root.maxVisibleRows)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.moveSelection(root.maxVisibleRows)
            event.accepted = true
          } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            root.favoriteSelected()
            event.accepted = true
          } else if (event.key >= Qt.Key_F1 && event.key < Qt.Key_F1 + root.maxVisibleRows) {
            if (root.activateVisible(event.key - Qt.Key_F1)) {
              event.accepted = true
            }
          }
        }
        Keys.onEscapePressed: Panels.close()
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.surfaceHigh
    }
  }

  Item {
    id: swapArea

    width: parent.width
    height: morphCard.visible && list.visible ? morphCard.emptyHeight : (morphCard.visible ? morphCard.height : list.height)
    clip: true

    Rectangle {
      id: morphCard

      property string mode: root.rowCount === 0 ? "empty" : "command"
      readonly property int emptyHeight: 2 * root.rowHeight + Theme.gap

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: morphCard.mode === "empty" ? morphCard.emptyHeight : root.rowHeight
      visible: root.xfadeHold || root.rowCount === 0 || (root.commandMode && root.commandText.length > 0)
      z: 1
      radius: Theme.rowRadius
      color: Theme.surface
      antialiasing: true
      clip: true
      state: morphCard.mode

      onVisibleChanged: {
        if (visible) {
          Qt.callLater(root.snapMorphHeight)
          if (morphCard.mode === "empty") {
            emptyContent.opacity = 1
            commandContent.opacity = 0
          } else {
            emptyContent.opacity = 0
            commandContent.opacity = 1
          }
        }
      }

      states: [
        State {
          name: "empty"
          PropertyChanges {
            target: emptyContent
            opacity: 1
          }
          PropertyChanges {
            target: commandContent
            opacity: 0
          }
        },
        State {
          name: "command"
          PropertyChanges {
            target: emptyContent
            opacity: 0
          }
          PropertyChanges {
            target: commandContent
            opacity: 1
          }
        }
      ]

      transitions: [
        Transition {
          from: "empty"
          to: "command"
          SequentialAnimation {
            NumberAnimation {
              target: emptyContent
              property: "opacity"
              to: 0
              duration: 110
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              target: commandContent
              property: "opacity"
              to: 1
              duration: 110
              easing.type: Easing.OutCubic
            }
          }
        },
        Transition {
          from: "command"
          to: "empty"
          SequentialAnimation {
            NumberAnimation {
              target: commandContent
              property: "opacity"
              to: 0
              duration: 110
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              target: emptyContent
              property: "opacity"
              to: 1
              duration: 110
              easing.type: Easing.OutCubic
            }
          }
        }
      ]

      Behavior on height {
        id: morphHeightBehavior

        NumberAnimation {
          id: morphHeightAnim

          duration: 220
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: emptyContent

        anchors.centerIn: parent
        spacing: Math.round(8 * Theme.scale)

        Icon {
          anchors.horizontalCenter: parent.horizontalCenter
          name: "search"
          color: Theme.overlay
          font.pixelSize: Math.round(22 * Theme.scale)
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "No results"
          color: Theme.subtext
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
        }
      }

      Item {
        id: commandContent

        anchors.fill: parent
        opacity: 0

        Item {
          anchors.left: parent.left
          anchors.leftMargin: root.iconInset
          anchors.verticalCenter: parent.verticalCenter
          width: root.iconSlotSize
          height: width

          Icon {
            anchors.centerIn: parent
            name: "terminal"
            font.pixelSize: Math.round(20 * Theme.scale)
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: root.iconInset + root.iconSlotSize + root.textGap
          anchors.right: parent.right
          anchors.rightMargin: root.iconInset
          anchors.verticalCenter: parent.verticalCenter
          text: root.commandText
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        MouseArea {
          anchors.fill: parent
          onClicked: root.activateIndex(0)
        }

        MouseArea {
          anchors.fill: parent
          visible: root.xfadeActive
          hoverEnabled: true
        }
      }
    }

    SectionList {
      id: list

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      visible: !morphCard.visible || root.xfadeActive
      entries: root.shownEntries
      reorderAnimation: false
      fadeAnimation: false

      delegate: Item {
        id: entry

        required property string key
        required property string kind
        required property string section
        required property string label
        required property string itemKey
        required property bool active

        readonly property bool isCalc: kind === "calc"
        readonly property bool isImage: kind === "appimage"
        readonly property bool calcError: kind === "calc" && !!root.calc && !!root.calc.error
        readonly property var app: kind === "app" ? root.appForKey(itemKey) : null
        readonly property var image: kind === "appimage" ? root.imageForKey(itemKey) : null
        readonly property string appIconName: entry.app && entry.app.icon ? entry.app.icon : ""
        readonly property string appImagePath: entry.kind === "app" ? root.appImagePathFor(entry.app) : ""
        readonly property string appVersion: entry.kind === "app" ? root.versionForItem(itemKey) : ""
        readonly property string resolvedIcon: entry.image ? AppImages.iconFor(entry.image.path) : ""
        readonly property string imageName: entry.image ? AppImages.nameFor(entry.image.path) : ""
        readonly property string imageVersion: entry.image ? AppImages.versionFor(entry.image.path) : ""
        readonly property string placeholderIcon: entry.isImage ? Quickshell.iconPath("application-vnd.appimage", "application-x-executable") : ""
        readonly property bool twoLine: entry.isCalc || entry.isImage || entry.appVersion.length > 0
        readonly property bool favoritable: entry.kind === "app" || entry.isImage
        readonly property bool favorite: entry.favoritable && Favorites.has(entry.itemKey)
        readonly property string subtitle: {
          if (entry.isCalc) {
            return root.calcExpression()
          }
          if (entry.isImage) {
            return entry.imageVersion.length > 0 ? entry.imageVersion : (entry.image ? entry.image.detail : "")
          }
          return entry.appVersion
        }
        readonly property string imageSource: {
          if (entry.kind === "app") {
            if (entry.appIconName.length > 0 && entry.appIconName.charAt(0) === "/") {
              return "file://" + entry.appIconName
            }
            if (ThemeIcons.has(entry.appIconName)) {
              return Quickshell.iconPath(entry.appIconName, "")
            }
            return entry.appImagePath.length > 0 ? AppImages.iconFor(entry.appImagePath) : ""
          }
          if (entry.isImage) {
            return entry.resolvedIcon.length > 0 ? entry.resolvedIcon : entry.placeholderIcon
          }
          return ""
        }
        readonly property bool showsImage: entry.imageSource.length > 0 && rowIcon.status !== Image.Error
        readonly property string glyphName: entry.isCalc ? "calculator" : (entry.kind === "command" ? "terminal" : "app-window")
        readonly property string title: {
          if (kind === "calc") {
            return root.calc && root.calc.value !== null ? root.formatDisplay(root.calc.value) : ""
          }
          if (kind === "command") {
            return root.commandText
          }
          if (kind === "appimage") {
            return entry.imageName.length > 0 ? entry.imageName : (image ? image.name : "")
          }
          return app && app.name ? app.name : ""
        }

        width: list.width
        height: root.rowHeight

        Rectangle {
          anchors.fill: parent
          radius: Theme.rowRadius
          color: entry.active || rowMouse.containsMouse || star.hovered ? Theme.surface : "transparent"

          Item {
            id: iconSlot

            anchors.left: parent.left
            anchors.leftMargin: root.iconInset
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSlotSize
            height: width

            Image {
              id: rowIcon

              anchors.fill: parent
              visible: entry.showsImage
              sourceSize: Qt.size(width, height)
              source: entry.imageSource
            }

            Icon {
              anchors.centerIn: parent
              visible: !entry.showsImage
              name: entry.glyphName
              font.pixelSize: Math.round(20 * Theme.scale)
            }
          }

          Column {
            anchors.left: iconSlot.right
            anchors.leftMargin: root.textGap
            anchors.right: parent.right
            anchors.rightMargin: root.rowTextRight
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * Theme.scale)
            visible: entry.twoLine

            Text {
              width: parent.width
              visible: !entry.calcError
              text: entry.title
              color: Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              width: parent.width
              text: entry.subtitle
              textFormat: entry.isCalc ? Text.StyledText : Text.PlainText
              color: Theme.overlay
              font.family: Theme.fontFamily
              font.pixelSize: entry.isCalc ? Theme.fontSizeSmall : root.subtitleSize
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Item {
              width: parent.width
              height: caretGlyph.implicitHeight
              visible: entry.calcError

              Text {
                id: caretGlyph

                x: exprMetrics.width
                text: "^"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }
            }
          }

          TextMetrics {
            id: exprMetrics

            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            text: entry.calcError ? root.calc.expression.substring(0, root.calc.error.start) : ""
          }

          Text {
            anchors.left: iconSlot.right
            anchors.leftMargin: root.textGap
            anchors.right: parent.right
            anchors.rightMargin: root.rowTextRight
            anchors.verticalCenter: parent.verticalCenter
            visible: !entry.twoLine
            text: entry.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }

        MouseArea {
          id: rowMouse

          anchors.fill: parent
          hoverEnabled: true
          onContainsMouseChanged: if (containsMouse) {
            root.selectedIndex = index
          }
          onClicked: root.activateIndex(index)
        }

        IconButton {
          id: star

          anchors.right: parent.right
          anchors.rightMargin: root.iconInset
          anchors.verticalCenter: parent.verticalCenter
          visible: entry.favoritable
          size: root.starSize
          glyphSize: Math.round(16 * Theme.scale)
          name: entry.favorite ? "star-filled" : "star"
          iconColor: entry.favorite ? Theme.yellow : (hovered ? Theme.text : Theme.overlay)
          hoverColor: "transparent"
          onClicked: root.toggleFavoriteItem(entry.itemKey)
        }
      }
    }
  }
}
