pragma Singleton
import Quickshell
import "../theme"

Singleton {
  id: root

  readonly property string key: "kbbi"
  readonly property string name: "KBBI"
  readonly property string desc: "Official Indonesian dictionary (KBBI VI)"
  readonly property url logo: "../assets/kbbi.svg"
  readonly property var params: []
  readonly property string errorText: "KBBI lookup failed"

  readonly property int maxItems: 8

  readonly property var palette: [Theme.primary, Theme.green, Theme.yellow, Theme.red, Qt.color("#cba6f7"), Qt.color("#f5c2e7"), Qt.color("#94e2d5"), Qt.color("#fab387")]

  function termOf(text) {
    return String(text === undefined || text === null ? "" : text).trim().toLowerCase()
  }

  function buildUrl(ctx) {
    const term = root.termOf(ctx.term)
    if (term.length === 0) {
      return ""
    }
    return "https://kbbi.kemendikdasmen.go.id/entri/" + encodeURIComponent(term)
  }

  function requestArgs(url) {
    return ["curl", "-s", "--compressed", "--max-time", "10", "-A", "Mozilla/5.0 (X11; Linux x86_64)", url]
  }

  function parse(text) {
    const raw = String(text === undefined || text === null ? "" : text).trim()
    if (raw.length === 0) {
      return {
        results: [],
        error: root.errorText
      }
    }
    const items = root.mapItems(raw)
    if (items.length === 0) {
      return {
        results: [],
        error: "Not found in KBBI"
      }
    }
    return {
      results: items,
      error: ""
    }
  }

  function mock(payload) {
    return root.parse(payload)
  }

  function rows(ctx) {
    if (ctx.error.length > 0) {
      return [root.errorRow(ctx.error)]
    }
    const out = []
    const results = ctx.results || []
    for (let i = 0; i < results.length; i++) {
      const item = results[i]
      out.push({
        key: "kbbi:" + i,
        title: root.titleRich(item.word, item.syn),
        titleRich: true,
        titleColor: Theme.overlay,
        subtitle: root.defRich(item.def, item.example),
        subtitleRich: true,
        subtitleColor: Theme.text,
        glyph: "",
        image: "",
        badge: String(i + 1),
        badgeColor: i < root.palette.length ? root.palette[i] : Theme.surfaceHigh,
        action: "copy",
        copyText: item.def
      })
    }
    return out
  }

  function cardTitle(ctx) {
    if (ctx.state === "loading") {
      return "Searching KBBI..."
    }
    if (ctx.state === "search") {
      return "Search KBBI for \"" + ctx.term + "\""
    }
    return root.name
  }

  function cardHint(ctx) {
    if (ctx.state === "loading") {
      return ctx.term
    }
    if (ctx.state === "search") {
      return "Press Enter to look up"
    }
    return "Type @" + root.key + " <word> then Enter to look up"
  }

  function errorRow(message) {
    return {
      key: "kbbi:error",
      title: String(message === undefined || message === null || message === "" ? root.errorText : message),
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

  function mapItems(html) {
    const out = []
    const blocks = root.entryBlocks(html)
    for (let i = 0; i < blocks.length; i++) {
      const word = root.entryName(blocks[i].heading)
      if (word.length === 0) {
        continue
      }
      const meanings = root.meaningsOf(blocks[i].list)
      for (let j = 0; j < meanings.length && out.length < root.maxItems; j++) {
        out.push({
          word: word,
          syn: meanings[j].syn,
          def: meanings[j].def,
          example: meanings[j].example
        })
      }
    }
    return out
  }

  function entryBlocks(html) {
    const out = []
    const raw = String(html === undefined || html === null ? "" : html)
    const limit = root.contentEnd(raw)
    const re = /<h2 style="margin-bottom:3px">([\s\S]*?)<\/h2>/g
    const heads = []
    let match = re.exec(raw)
    while (match !== null && match.index < limit) {
      heads.push({
        heading: match[1],
        start: match.index,
        end: re.lastIndex
      })
      match = re.exec(raw)
    }
    for (let i = 0; i < heads.length; i++) {
      const stop = i + 1 < heads.length ? heads[i + 1].start : limit
      out.push({
        heading: heads[i].heading,
        list: root.listOf(raw.slice(heads[i].end, stop))
      })
    }
    return out
  }

  function contentEnd(html) {
    const marker = html.indexOf("Pesan Redaksi")
    if (marker < 0) {
      return html.length
    }
    const head = html.lastIndexOf("<h4", marker)
    return head < 0 ? marker : head
  }

  function listOf(body) {
    const raw = String(body)
    const ordered = raw.indexOf("<ol")
    const unordered = raw.indexOf("<ul")
    let at = -1
    let close = "</ol>"
    if (ordered >= 0 && (unordered < 0 || ordered < unordered)) {
      at = ordered
    } else if (unordered >= 0) {
      at = unordered
      close = "</ul>"
    }
    if (at < 0) {
      return ""
    }
    const end = raw.indexOf(close, at)
    return end < 0 ? raw.slice(at) : raw.slice(at, end)
  }

  function entryName(heading) {
    let text = String(heading)
    text = text.replace(/<span class="rootword">[\s\S]*?<\/span>/g, "")
    text = text.replace(/<small>[\s\S]*?<\/small>/g, "")
    text = text.replace(/<sup>(\d)<\/sup>/g, root.supMark)
    return root.plainText(text).replace(/\s*»\s*$/, "").trim()
  }

  function supMark(match, digit) {
    return root.superscript(digit)
  }

  function superscript(number) {
    const key = String(number)
    const digits = "0123456789"
    const marks = "⁰¹²³⁴⁵⁶⁷⁸⁹"
    const at = key.length === 1 ? digits.indexOf(key) : -1
    return at >= 0 ? marks.charAt(at) : key
  }

  function meaningsOf(list) {
    const out = []
    const parts = String(list).split(/<li\b[^>]*>/i)
    for (let i = 1; i < parts.length; i++) {
      const end = parts[i].indexOf("</li>")
      const item = end < 0 ? parts[i] : parts[i].slice(0, end)
      const def = root.definitionOf(item)
      if (def.length === 0) {
        continue
      }
      out.push({
        syn: root.labelsOf(item),
        def: def,
        example: root.exampleOf(item)
      })
    }
    return out
  }

  function labelsOf(item) {
    const out = []
    const block = root.labelBlock(item)
    const re = /<span title="([^"]*)">([\s\S]*?)<\/span>/g
    let match = re.exec(block)
    while (match !== null) {
      const code = root.plainText(match[2])
      if (code.length === 0) {
        break
      }
      const title = String(match[1])
      const cut = title.indexOf(":")
      const name = cut > 0 ? title.slice(0, cut).trim() : title.trim()
      out.push(name.length > 0 ? name : code)
      match = re.exec(block)
    }
    return out.join(", ")
  }

  function labelBlock(item) {
    const raw = String(item)
    const at = raw.indexOf('<font color="red">')
    if (at < 0) {
      return ""
    }
    let depth = 0
    let index = at
    while (index < raw.length) {
      const open = raw.indexOf("<font", index)
      const close = raw.indexOf("</font>", index)
      if (close < 0) {
        break
      }
      if (open >= 0 && open < close) {
        depth++
        index = open + 5
        continue
      }
      depth--
      index = close + 7
      if (depth === 0) {
        return raw.slice(at, index)
      }
    }
    return raw.slice(at)
  }

  function definitionOf(item) {
    const raw = String(item)
    const block = root.labelBlock(raw)
    let text = block.length > 0 ? raw.replace(block, "") : raw
    text = text.replace(/<font color="grey">[\s\S]*?<\/font>/g, "")
    text = root.plainText(text)
    text = text.replace(/^\s*[:;]\s*/, "")
    return text.replace(/\s*[;:]\s*$/, "")
  }

  function exampleOf(item) {
    const re = /<font color="grey">([\s\S]*?)<\/font>/g
    const raw = String(item)
    let match = re.exec(raw)
    while (match !== null) {
      const text = root.plainText(match[1])
      if (text.length > 0 && !/^[\s;:.,]+$/.test(text)) {
        return text
      }
      match = re.exec(raw)
    }
    return ""
  }

  function plainText(html) {
    let text = String(html === undefined || html === null ? "" : html)
    text = text.replace(/<[^>]*>/g, "")
    text = text.replace(/&#x21E2;/g, "⇒").replace(/&copy;/g, "©").replace(/&nbsp;/g, " ").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
    return text.replace(/\s+/g, " ").trim()
  }

  function escapeHtml(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  function defRich(plain, example) {
    const text = root.escapeHtml(plain)
    if (!example || String(example).length === 0) {
      return text
    }
    return text + " · <i>" + root.escapeHtml(example) + "</i>"
  }

  function titleRich(word, syn) {
    const head = "<font color=\"" + Colors.hex(Theme.text) + "\">" + root.escapeHtml(word) + "</font>"
    if (!syn || String(syn).length === 0) {
      return head
    }
    return head + "<font color=\"" + Colors.hex(Theme.overlay) + "\" size=\"-2\"> " + root.escapeHtml(syn) + "</font>"
  }
}
