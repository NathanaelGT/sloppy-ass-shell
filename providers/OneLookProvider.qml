pragma Singleton
import Quickshell
import "../theme"

Singleton {
  id: root

  readonly property string key: "ol"
  readonly property string name: "OneLook"
  readonly property string desc: "Find English definition and related words"
  readonly property url logo: "../assets/onelook.svg"
  readonly property var params: []
  readonly property string errorText: "Search failed"

  readonly property var palette: [Theme.primary, Theme.green, Theme.yellow, Theme.red, Qt.color("#cba6f7"), Qt.color("#f5c2e7"), Qt.color("#94e2d5"), Qt.color("#fab387")]

  function buildUrl(ctx) {
    return "https://onelook.com/api/sug?max=9&s=" + encodeURIComponent(ctx.term)
  }

  function requestArgs(url) {
    return ["curl", "-s", "--max-time", "10", "-A", "Mozilla/5.0", "-H", "Referer: https://www.onelook.com/", url]
  }

  function parse(text) {
    let data = null
    try {
      data = JSON.parse(text)
    } catch (e) {
      data = null
    }
    if (!data || typeof data.length !== "number") {
      return {
        results: [],
        error: root.errorText
      }
    }
    return {
      results: root.mapItems(data),
      error: ""
    }
  }

  function mock(payload) {
    let data = null
    try {
      data = JSON.parse(payload)
    } catch (e) {
      data = null
    }
    if (data && data.items && typeof data.items.length === "number") {
      data = data.items
    }
    if (!data || typeof data.length !== "number") {
      return {
        results: [],
        error: root.errorText
      }
    }
    return {
      results: root.mapItems(data),
      error: ""
    }
  }

  function rows(ctx) {
    if (ctx.error.length > 0) {
      return [root.errorRow()]
    }
    const out = []
    const results = ctx.results || []
    for (let i = 0; i < results.length; i++) {
      const item = results[i]
      out.push({
        key: "ol:" + i,
        title: root.titleRich(item.word, item.syn),
        titleRich: true,
        titleColor: Theme.overlay,
        subtitle: root.defRich(item.def),
        subtitleRich: true,
        subtitleColor: Theme.text,
        glyph: "",
        image: "",
        badge: String(i + 1),
        badgeColor: i < root.palette.length ? root.palette[i] : Theme.surfaceHigh,
        action: "copy",
        copyText: item.word
      })
    }
    return out
  }

  function cardTitle(ctx) {
    if (ctx.state === "loading") {
      return "Searching OneLook..."
    }
    if (ctx.state === "search") {
      return "Search OneLook for \"" + ctx.term + "\""
    }
    return root.name
  }

  function cardHint(ctx) {
    if (ctx.state === "loading") {
      return ctx.term
    }
    if (ctx.state === "search") {
      return "Press Enter to search"
    }
    return "Type @" + root.key + " <word> then Enter to search"
  }

  function errorRow() {
    return {
      key: "ol:error",
      title: root.errorText,
      titleRich: false,
      titleColor: Theme.text,
      subtitle: "Press Enter to retry",
      subtitleRich: false,
      subtitleColor: Theme.overlay,
      glyph: "search",
      image: "",
      badge: "",
      badgeColor: Theme.surfaceHigh,
      action: "search",
      copyText: ""
    }
  }

  function mapItems(data) {
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
      const split = root.splitBrackets(root.cleanDef(raw))
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

  function cleanDef(raw) {
    return String(raw === undefined || raw === null ? "" : raw).trim().replace(/^[A-Za-z]+\t+/, "").trim()
  }

  function splitBrackets(cleaned) {
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

  function defRich(plain) {
    const e = String(plain).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const paired = e.replace(/_([^_]+)_/g, "<i>$1</i>")
    return paired.replace(/_([^\s_]+)/g, "<i>$1</i>")
  }

  function titleRich(word, syn) {
    const w = String(word).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const head = "<font color=\"" + Colors.hex(Theme.text) + "\">" + w + "</font>"
    if (!syn || String(syn).length === 0) {
      return head
    }
    return head + "<font color=\"" + Colors.hex(Theme.overlay) + "\" size=\"-2\"> " + root.defRich(syn) + "</font>"
  }
}
