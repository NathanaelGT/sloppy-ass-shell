import QtQuick
import Quickshell
import Quickshell.Io
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
  property int iconRefreshTick: 0
  property string olSearchedTerm: ""
  property var olResults: []
  property bool olLoading: false
  property string olError: ""

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

  readonly property var atProviders: [
    {
      key: "ol",
      name: "OneLook",
      desc: "Find English definition and related words",
      logo: "../assets/onelook.svg"
    },
    {
      key: "tr",
      name: "Translate",
      desc: "Translate words and sentences",
      logo: "../assets/google-translate.svg"
    }
  ]

  readonly property bool atMode: root.query.trim().toLowerCase().indexOf("@") === 0
  readonly property string atToken: root.atMode ? root.query.trim().slice(1).split(/\s+/)[0].toLowerCase() : ""
  readonly property var atMatches: {
    if (!root.atMode || root.olMode || root.trMode) {
      return []
    }
    const out = []
    for (let i = 0; i < root.atProviders.length; i++) {
      if (root.atProviders[i].key.indexOf(root.atToken) === 0) {
        out.push(root.atProviders[i])
      }
    }
    return out
  }
  readonly property int atRowCount: root.atMode && !root.olMode && !root.trMode ? root.atMatches.length : 0

  readonly property bool olMode: {
    const t = root.query.trim().toLowerCase()
    return t === "@ol" || t.indexOf("@ol ") === 0
  }
  readonly property string olTerm: root.olMode ? root.query.trim().slice(3).trim() : ""
  readonly property bool olDirty: root.olTerm !== root.olSearchedTerm
  readonly property string olCard: {
    if (!root.olMode) {
      return ""
    }
    if (root.olTerm.length === 0) {
      return "hint"
    }
    if (root.olDirty) {
      return "search"
    }
    if (root.olLoading) {
      return "loading"
    }
    return ""
  }
  readonly property int olRowCount: {
    if (!root.olMode) {
      return 0
    }
    if (root.olCard.length > 0) {
      return 0
    }
    if (root.olError.length > 0) {
      return 1
    }
    return root.olResults.length
  }
  property string trSearchedSpec: ""
  property string trSearchedTerm: ""
  property string trResult: ""
  property bool trLoading: false
  property string trError: ""

  readonly property bool trMode: {
    const t = root.query.trim().toLowerCase()
    return t === "@tr" || t.indexOf("@tr ") === 0
  }
  readonly property string trRest: root.trMode ? root.query.trim().slice(3).trim() : ""
  readonly property var trParts: root.trRest.length === 0 ? [] : root.trRest.split(/\s+/)
  readonly property string trSpec: {
    if (root.trParts.length === 0) {
      return ""
    }
    const s = root.trParts[0].toLowerCase()
    if (/^[a-z]{2}([a-z]{2})?$/.test(s)) {
      return s
    }
    return ""
  }
  readonly property string trTerm: root.trSpec.length > 0 ? root.trParts.slice(1).join(" ") : ""
  readonly property string trSource: root.trSpec.length === 4 ? root.trSpec.slice(0, 2) : "auto"
  readonly property string trTarget: root.trSpec.length === 4 ? root.trSpec.slice(2) : root.trSpec
  readonly property string trDir: root.trSource + " → " + root.trTarget
  readonly property bool trDirty: root.trSpec !== root.trSearchedSpec || root.trTerm !== root.trSearchedTerm
  readonly property string trCard: {
    if (!root.trMode) {
      return ""
    }
    if (root.trSpec.length === 0 || root.trTerm.length === 0) {
      return "hint"
    }
    if (root.trDirty) {
      return "search"
    }
    if (root.trLoading) {
      return "loading"
    }
    return ""
  }
  readonly property int trRowCount: {
    if (!root.trMode) {
      return 0
    }
    if (root.trCard.length > 0) {
      return 0
    }
    return 1
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
  readonly property int rowCount: root.atMode ? (root.olMode ? root.olRowCount : (root.trMode ? root.trRowCount : root.atRowCount)) : (commandMode ? (commandText.length > 0 ? 1 : 0) : results.length + (calc ? 1 : 0))
  readonly property int selected: rowCount === 0 ? -1 : Math.max(0, Math.min(selectedIndex, rowCount - 1))

  readonly property var entries: {
    const out = []
    if (root.atMode && !root.olMode && !root.trMode) {
      for (let i = 0; i < root.atMatches.length; i++) {
        out.push({
          kind: "provider",
          section: "",
          label: "",
          itemKey: "provider:" + root.atMatches[i].key,
          active: selected === out.length
        })
      }
      return out
    }
    if (root.olMode) {
      if (root.olError.length > 0) {
        out.push({
          kind: "olError",
          section: "",
          label: "",
          itemKey: "ol:error",
          active: selected === 0
        })
      } else if (root.olCard.length === 0) {
        for (let i = 0; i < root.olResults.length; i++) {
          out.push({
            kind: "onelook",
            section: "",
            label: "",
            itemKey: "ol:" + i,
            active: selected === out.length
          })
        }
      }
      return out
    }
    if (root.trMode) {
      if (root.trCard.length > 0) {
        return out
      }
      if (root.trError.length > 0) {
        out.push({
          kind: "trError",
          section: "",
          label: "",
          itemKey: "tr:error",
          active: selected === 0
        })
      } else if (root.trResult.length > 0) {
        out.push({
          kind: "translate",
          section: "",
          label: "",
          itemKey: "tr:0",
          active: selected === 0
        })
      }
      return out
    }
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

  function hexOf(color) {
    function channel(v) {
      return Math.round(v * 255).toString(16).padStart(2, "0")
    }
    return "#" + channel(color.r) + channel(color.g) + channel(color.b)
  }

  function errorHex() {
    return root.hexOf(Theme.red)
  }

  function olMutedHex() {
    return root.hexOf(Theme.overlay)
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

  function testAppIcon(app, itemKey) {
    const target = app ? app : root.appForKey(itemKey)
    const iconName = target && target.icon ? target.icon : ""
    if (iconName.length > 0 && iconName.charAt(0) === "/") {
      return "file://" + iconName
    }
    if (ThemeIcons.has(iconName)) {
      return Quickshell.iconPath(iconName, "")
    }
    const imagePath = root.appImagePathFor(target)
    return imagePath.length > 0 ? AppImages.iconFor(imagePath) : ""
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

  function cleanOlDef(raw) {
    const s = String(raw === undefined || raw === null ? "" : raw).trim().replace(/^[A-Za-z]+\t+/, "").trim()
    return s
  }

  function olRichDef(plain) {
    const e = String(plain).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const paired = e.replace(/_([^_]+)_/g, "<i>$1</i>")
    return paired.replace(/_([^\s_]+)/g, "<i>$1</i>")
  }

  function olIndexForKey(itemKey) {
    const text = String(itemKey)
    if (text.indexOf("ol:") !== 0) {
      return -1
    }
    const n = parseInt(text.slice(3), 10)
    if (isNaN(n)) {
      return -1
    }
    return n
  }

  function olItemForKey(itemKey) {
    const n = root.olIndexForKey(itemKey)
    if (n < 0 || n >= root.olResults.length) {
      return null
    }
    return root.olResults[n]
  }

  function splitOlBrackets(cleaned) {
    const text = String(cleaned)
    const groups = text.match(/\[[^\]]*\]/g)
    let syn = ""
    if (groups && groups.length > 0) {
      syn = groups[0].slice(1, -1).trim()
    }
    return {
      text: text.replace(/\[[^\]]*\]/g, "").replace(/\s+/g, " ").trim(),
      syn: syn
    }
  }

  function olTitleRich(word, syn) {
    const w = String(word).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const head = "<font color=\"" + root.hexOf(Theme.text) + "\">" + w + "</font>"
    if (!syn || String(syn).length === 0) {
      return head
    }
    return head + "<font color=\"" + root.olMutedHex() + "\" size=\"-2\"> " + root.olRichDef(syn) + "</font>"
  }

  function providerForKey(key) {
    for (let i = 0; i < root.atProviders.length; i++) {
      if (root.atProviders[i].key === key) {
        return root.atProviders[i]
      }
    }
    return null
  }

  function completeAtProvider(itemKey) {
    const text = String(itemKey)
    const key = text.indexOf("provider:") === 0 ? text.slice(9) : ""
    const provider = root.providerForKey(key)
    if (!provider) {
      return false
    }
    searchInput.text = "@" + provider.key + " "
    searchInput.forceActiveFocus()
    return true
  }

  function mapOlItems(data) {
    const out = []
    if (!data || typeof data.length !== "number") {
      return out
    }
    for (let i = 0; i < data.length && out.length < 8; i++) {
      const item = data[i]
      const word = item && item.word ? String(item.word) : ""
      if (word.length === 0) {
        continue
      }
      let raw = ""
      if (item.defs && typeof item.defs.length === "number" && item.defs.length > 0) {
        raw = item.defs[0]
      }
      const split = root.splitOlBrackets(root.cleanOlDef(raw))
      if (split.text.length === 0) {
        continue
      }
      out.push({
        word: word,
        def: split.text,
        syn: split.syn
      })
    }
    return out
  }

  function runOlSearch() {
    if (!root.olMode || root.olTerm.length === 0 || root.olLoading) {
      return false
    }
    if (!root.olDirty && (root.olResults.length > 0 || root.olError.length > 0)) {
      return false
    }
    root.olSearchedTerm = root.olTerm
    root.olResults = []
    root.olError = ""
    root.olLoading = true
    const url = "https://onelook.com/api/sug?max=9&s=" + encodeURIComponent(root.olTerm)
    if (olProc.running) {
      olProc.running = false
    }
    olProc.command = ["curl", "-s", "--max-time", "10", "-A", "Mozilla/5.0", "-H", "Referer: https://www.onelook.com/", url]
    olProc.running = true
    return true
  }

  function handleOlOutput(text) {
    if (!root.olLoading) {
      return
    }
    let data = null
    try {
      data = JSON.parse(text)
    } catch (e) {
      data = null
    }
    if (!data || typeof data.length !== "number") {
      root.olError = "Search failed"
      root.olResults = []
      root.olLoading = false
      return
    }
    root.olResults = root.mapOlItems(data)
    root.olError = ""
    root.olLoading = false
  }

  function handleOlExit(code) {
    if (!root.olLoading) {
      return
    }
    if (code !== 0) {
      root.olError = "Search failed"
      root.olResults = []
      root.olLoading = false
    }
  }

  function testOlMock(payload) {
    let data = null
    try {
      data = JSON.parse(payload)
    } catch (e) {
      return false
    }
    if (data && data.items && typeof data.items.length === "number") {
      data = data.items
    }
    root.olSearchedTerm = root.olTerm
    root.olResults = root.mapOlItems(data)
    root.olError = ""
    root.olLoading = false
    return true
  }

  function mapTrTranslation(data) {
    if (typeof data === "string") {
      return data.trim()
    }
    if (!data || typeof data.length !== "number" || data.length === 0) {
      return ""
    }
    const segments = data[0]
    if (!segments || typeof segments.length !== "number") {
      return ""
    }
    const parts = []
    for (let i = 0; i < segments.length; i++) {
      if (segments[i] && typeof segments[i][0] === "string") {
        parts.push(segments[i][0])
      }
    }
    return parts.join("").trim()
  }

  function runTrSearch() {
    if (!root.trMode || root.trTerm.length === 0 || root.trLoading) {
      return false
    }
    if (!root.trDirty && (root.trResult.length > 0 || root.trError.length > 0)) {
      return false
    }
    root.trSearchedSpec = root.trSpec
    root.trSearchedTerm = root.trTerm
    root.trResult = ""
    root.trError = ""
    root.trLoading = true
    const url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" + root.trSource + "&tl=" + root.trTarget + "&dt=t&q=" + encodeURIComponent(root.trTerm)
    if (trProc.running) {
      trProc.running = false
    }
    trProc.command = ["/nix/store/k2z212kirkjxi3n7ghvd8w4ha54q295c-curl-8.22.0-bin/bin/curl", "-s", "--max-time", "10", "-A", "Mozilla/5.0", "--http1.1", url]
    trProc.running = true
    return true
  }

  function handleTrOutput(text) {
    if (!root.trLoading) {
      return
    }
    let data = null
    try {
      data = JSON.parse(text)
    } catch (e) {
      data = null
    }
    const translation = root.mapTrTranslation(data)
    if (translation.length === 0) {
      root.trError = "Translation failed"
      root.trResult = ""
      root.trLoading = false
      return
    }
    root.trResult = translation
    root.trError = ""
    root.trLoading = false
  }

  function handleTrExit(code) {
    if (!root.trLoading) {
      return
    }
    if (code !== 0) {
      root.trError = "Translation failed"
      root.trResult = ""
      root.trLoading = false
    }
  }

  function testTrMock(payload) {
    let data = null
    try {
      data = JSON.parse(payload)
    } catch (e) {
      return false
    }
    if (data && typeof data.translation === "string") {
      data = data.translation
    }
    const translation = root.mapTrTranslation(data)
    if (translation.length === 0) {
      return false
    }
    root.trSearchedSpec = root.trSpec
    root.trSearchedTerm = root.trTerm
    root.trResult = translation
    root.trError = ""
    root.trLoading = false
    return true
  }

  function kittyArgv(command) {
    return ["kitty", "--hold", "-d", Quickshell.env("HOME"), "--class", "command-runner", "-o", "confirm_os_window_close=0", "-e", "bash", "-lc", command]
  }

  function acceptCurrent() {
    if (root.selected >= 0) {
      return root.activateIndex(root.selected)
    }
    if (root.olCard === "search") {
      return root.runOlSearch()
    }
    if (root.trCard === "search") {
      return root.runTrSearch()
    }
    return false
  }

  function activateIndex(index) {
    const entry = entries[index]
    if (!entry) {
      return false
    }
    if (entry.kind === "provider") {
      return root.completeAtProvider(entry.itemKey)
    }
    if (entry.kind === "olError") {
      return root.runOlSearch()
    }
    if (entry.kind === "trError") {
      return root.runTrSearch()
    }
    if (entry.kind === "translate") {
      if (root.trResult.length === 0) {
        return false
      }
      Quickshell.clipboardText = root.trResult
      Panels.close()
      return true
    }
    if (entry.kind === "onelook") {
      const item = root.olItemForKey(entry.itemKey)
      if (!item) {
        return false
      }
      Quickshell.clipboardText = item.word
      Panels.close()
      return true
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
      let syn = ""
      let icon = ""
      if (entry.kind === "calc") {
        name = root.calc && root.calc.value !== null ? root.formatDisplay(root.calc.value) : ""
        detail = root.calc ? root.calc.expression : ""
      } else if (entry.kind === "command") {
        name = root.commandText
      } else if (entry.kind === "onelook") {
        const item = root.olItemForKey(entry.itemKey)
        name = item ? item.word : ""
        detail = item ? item.def : ""
        syn = item ? item.syn : ""
        icon = ""
      } else if (entry.kind === "provider") {
        const provider = root.providerForKey(String(entry.itemKey).slice(9))
        name = provider ? provider.name : entry.itemKey
        detail = provider ? provider.desc : ""
        icon = provider ? provider.logo : ""
      } else if (entry.kind === "olError") {
        name = "Search failed"
        detail = "Press Enter to retry"
      } else if (entry.kind === "translate") {
        name = root.trResult
        detail = root.trTerm
        icon = ""
      } else if (entry.kind === "trError") {
        name = "Translation failed"
        detail = "Press Enter to retry"
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
        icon = root.testAppIcon(app, entry.itemKey)
      }
      const match = scored[entry.itemKey]
      rows.push({
        kind: entry.kind,
        name: name,
        detail: detail,
        syn: syn,
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
      atMode: root.atMode,
      atToken: root.atToken,
      olMode: root.olMode,
      olTerm: root.olTerm,
      olCard: root.olCard,
      olLoading: root.olLoading,
      olError: root.olError,
      trMode: root.trMode,
      trSpec: root.trSpec,
      trSource: root.trSource,
      trTarget: root.trTarget,
      trTerm: root.trTerm,
      trCard: root.trCard,
      trLoading: root.trLoading,
      trError: root.trError,
      trResult: root.trResult,
      clipboard: Quickshell.clipboardText,
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
      providerOpacity: providerContent.opacity,
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
    return root.acceptCurrent()
  }

  function snapMorphHeight() {
    if (!morphCard.visible) {
      return
    }
    morphHeightBehavior.enabled = false
    morphHeightAnim.stop()
    morphCard.height = Qt.binding(function () {
      return morphCard.mode === "command" ? root.rowHeight : morphCard.emptyHeight
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

  Process {
    id: olProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: root.handleOlOutput(text)
    }
    onExited: code => root.handleOlExit(code)
  }

  Process {
    id: trProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: root.handleTrOutput(text)
    }
    onExited: code => root.handleTrExit(code)
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
    root.iconRefreshTick += 1
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
        onAccepted: root.acceptCurrent()

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

      property string mode: root.rowCount === 0 ? ((root.olCard.length > 0 || root.trCard.length > 0) ? "provider" : "empty") : "command"
      readonly property int emptyHeight: 2 * root.rowHeight + Theme.gap

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: morphCard.mode === "command" ? root.rowHeight : morphCard.emptyHeight
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
            providerContent.opacity = 0
          } else if (morphCard.mode === "provider") {
            emptyContent.opacity = 0
            commandContent.opacity = 0
            providerContent.opacity = 1
          } else {
            emptyContent.opacity = 0
            commandContent.opacity = 1
            providerContent.opacity = 0
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
          PropertyChanges {
            target: providerContent
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
          PropertyChanges {
            target: providerContent
            opacity: 0
          }
        },
        State {
          name: "provider"
          PropertyChanges {
            target: emptyContent
            opacity: 0
          }
          PropertyChanges {
            target: commandContent
            opacity: 0
          }
          PropertyChanges {
            target: providerContent
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
        },
        Transition {
          from: "empty"
          to: "provider"
          SequentialAnimation {
            NumberAnimation {
              target: emptyContent
              property: "opacity"
              to: 0
              duration: 110
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              target: providerContent
              property: "opacity"
              to: 1
              duration: 110
              easing.type: Easing.OutCubic
            }
          }
        },
        Transition {
          from: "provider"
          to: "empty"
          SequentialAnimation {
            NumberAnimation {
              target: providerContent
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

      Column {
        id: providerContent

        anchors.centerIn: parent
        spacing: Math.round(4 * Theme.scale)
        opacity: 0

        Image {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.round(28 * Theme.scale)
          height: width
          source: root.trMode ? "../assets/google-translate.svg" : "../assets/onelook.svg"
          fillMode: Image.PreserveAspectFit
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.trMode ? (root.trCard === "loading" ? "Translating..." : (root.trCard === "search" ? "Translate \"" + root.trTerm + "\"" : "Translate")) : (root.olCard === "loading" ? "Searching OneLook..." : (root.olCard === "search" ? "Search OneLook for \"" + root.olTerm + "\"" : "OneLook"))
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.trMode ? (root.trCard === "loading" ? root.trTerm : (root.trCard === "search" ? "Press Enter to translate (" + root.trDir + ")" : "@tr id hello · @tr enid halo")) : (root.olCard === "loading" ? root.olTerm : (root.olCard === "search" ? "Press Enter to search" : "Type @ol <word> then Enter to search"))
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

      MouseArea {
        anchors.fill: parent
        visible: morphCard.mode === "provider" && (root.olCard === "search" || root.trCard === "search")
        onClicked: {
          if (root.olCard === "search") {
            root.runOlSearch()
          } else {
            root.runTrSearch()
          }
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

        property int iconTries: 0
        readonly property bool isCalc: kind === "calc"
        readonly property bool isImage: kind === "appimage"
        readonly property bool isOneLook: kind === "onelook"
        readonly property bool isProvider: kind === "provider"
        readonly property bool isOlMeta: kind === "olError"
        readonly property bool isTranslate: kind === "translate"
        readonly property bool isTrMeta: kind === "trError"
        readonly property int olIndex: entry.isOneLook ? root.olIndexForKey(itemKey) : -1
        readonly property color rankColor: {
          const palette = [Theme.primary, Theme.green, Theme.yellow, Theme.red, "#cba6f7", "#f5c2e7", "#94e2d5", "#fab387"]
          if (!entry.isOneLook || entry.olIndex < 0 || entry.olIndex >= palette.length) {
            return Theme.surfaceHigh
          }
          return palette[entry.olIndex]
        }
        readonly property bool calcError: kind === "calc" && !!root.calc && !!root.calc.error
        readonly property var app: kind === "app" ? root.appForKey(itemKey) : null
        readonly property var image: kind === "appimage" ? root.imageForKey(itemKey) : null
        readonly property string appVersion: entry.kind === "app" ? root.versionForItem(itemKey) : ""
        readonly property string resolvedIcon: entry.image ? AppImages.iconFor(entry.image.path) : ""
        readonly property string imageName: entry.image ? AppImages.nameFor(entry.image.path) : ""
        readonly property string imageVersion: entry.image ? AppImages.versionFor(entry.image.path) : ""
        readonly property string placeholderIcon: entry.isImage ? Quickshell.iconPath("application-vnd.appimage", "application-x-executable") : ""
        readonly property bool twoLine: entry.isCalc || entry.isImage || entry.isOneLook || entry.isProvider || entry.isOlMeta || entry.isTranslate || entry.isTrMeta || entry.appVersion.length > 0
        readonly property bool favoritable: entry.kind === "app" || entry.isImage
        readonly property bool favorite: entry.favoritable && Favorites.has(entry.itemKey)
        readonly property int textRightMargin: entry.favoritable ? root.rowTextRight : root.iconInset
        readonly property string subtitle: {
          if (entry.isCalc) {
            return root.calcExpression()
          }
          if (entry.isOneLook) {
            const arr = root.olResults
            const item = entry.olIndex >= 0 && entry.olIndex < arr.length ? arr[entry.olIndex] : null
            return item ? root.olRichDef(item.def) : ""
          }
          if (entry.kind === "olError") {
            return "Press Enter to retry"
          }
          if (entry.isTranslate) {
            return root.trTerm
          }
          if (entry.kind === "trError") {
            return "Press Enter to retry"
          }
          if (entry.isProvider) {
            const provider = root.providerForKey(String(itemKey).slice(9))
            return provider ? provider.desc : ""
          }
          if (entry.isImage) {
            return entry.imageVersion.length > 0 ? entry.imageVersion : (entry.image ? entry.image.detail : "")
          }
          return entry.appVersion
        }
        readonly property string imageSource: {
          root.iconRefreshTick
          if (entry.kind === "app") {
            return root.testAppIcon(entry.app, itemKey)
          }
          if (entry.isProvider) {
            const provider = root.providerForKey(String(itemKey).slice(9))
            return provider ? provider.logo : ""
          }
          if (entry.isImage) {
            return entry.resolvedIcon.length > 0 ? entry.resolvedIcon : entry.placeholderIcon
          }
          return ""
        }
        readonly property bool showsImage: entry.imageSource.length > 0 && rowIcon.status !== Image.Error
        readonly property string glyphName: entry.isCalc ? "calculator" : (entry.kind === "command" ? "terminal" : (entry.isTranslate ? "world" : ((entry.isProvider || entry.isOlMeta || entry.isTrMeta) ? "search" : "app-window")))
        readonly property string title: {
          if (kind === "calc") {
            return root.calc && root.calc.value !== null ? root.formatDisplay(root.calc.value) : ""
          }
          if (kind === "command") {
            return root.commandText
          }
          if (kind === "onelook") {
            const arr = root.olResults
            const item = entry.olIndex >= 0 && entry.olIndex < arr.length ? arr[entry.olIndex] : null
            return item ? root.olTitleRich(item.word, item.syn) : ""
          }
          if (kind === "provider") {
            const provider = root.providerForKey(String(itemKey).slice(9))
            return provider ? provider.name : ""
          }
          if (kind === "olError") {
            return "Search failed"
          }
          if (kind === "translate") {
            return root.trResult
          }
          if (kind === "trError") {
            return "Translation failed"
          }
          if (kind === "appimage") {
            return entry.imageName.length > 0 ? entry.imageName : (image ? image.name : "")
          }
          return app && app.name ? app.name : ""
        }

        onImageSourceChanged: entry.iconTries = 0

        Timer {
          id: iconRetry

          interval: 600
          onTriggered: {
            rowIcon.source = Qt.binding(function () {
              return entry.imageSource
            })
          }
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
              onStatusChanged: if (status === Image.Error && entry.imageSource.length > 0 && entry.iconTries < 3) {
                entry.iconTries += 1
                source = ""
                iconRetry.restart()
              }
            }

            Icon {
              anchors.centerIn: parent
              visible: !entry.showsImage && !entry.isOneLook
              name: entry.glyphName
              font.pixelSize: Math.round(20 * Theme.scale)
            }

            Rectangle {
              anchors.centerIn: parent
              visible: entry.isOneLook
              width: root.iconSlotSize
              height: width
              radius: Math.round(8 * Theme.scale)
              color: Qt.alpha(entry.rankColor, 0.5)

              Text {
                anchors.centerIn: parent
                text: entry.olIndex + 1
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(13 * Theme.scale)
                font.bold: true
              }
            }
          }

          Column {
            anchors.left: iconSlot.right
            anchors.leftMargin: root.textGap
            anchors.right: parent.right
            anchors.rightMargin: entry.textRightMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * Theme.scale)
            visible: entry.twoLine

            Text {
              width: parent.width
              visible: !entry.calcError
              text: entry.title
              textFormat: entry.isOneLook ? Text.StyledText : Text.PlainText
              color: entry.isOneLook ? Theme.overlay : Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            Text {
              width: parent.width
              text: entry.subtitle
              textFormat: (entry.isCalc || entry.isOneLook) ? Text.StyledText : Text.PlainText
              color: entry.isOneLook ? Theme.text : Theme.overlay
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
            anchors.rightMargin: entry.textRightMargin
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
