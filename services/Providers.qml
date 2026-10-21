pragma Singleton
import Quickshell
import "../providers"

Singleton {
  id: root

  readonly property int hiddenMinChars: 2

  readonly property var providers: [OneLookProvider, TranslateProvider]

  function providerForKey(key) {
    for (let i = 0; i < root.providers.length; i++) {
      if (root.providers[i].key === key) {
        return root.providers[i]
      }
    }
    return null
  }

  function paramsOf(provider) {
    if (!provider || !provider.params) {
      return []
    }
    return provider.params
  }

  function paramOf(provider, key) {
    const params = root.paramsOf(provider)
    for (let i = 0; i < params.length; i++) {
      if (params[i].key === key) {
        return params[i]
      }
    }
    return null
  }

  function defaultOf(param) {
    if (!param || param.default === undefined || param.default === null) {
      return undefined
    }
    return param.default
  }

  function hasDropdown(param) {
    if (!param) {
      return false
    }
    return param.type === "enum" || param.type === "bool"
  }

  function codeWidthOf(param) {
    if (!param || param.codeWidth === undefined || param.codeWidth === null) {
      return 0
    }
    return Number(param.codeWidth)
  }

  function distinctOf(param) {
    if (!param || !param.distinct) {
      return []
    }
    return param.distinct
  }

  function listOf(param) {
    if (!param) {
      return []
    }
    const out = []
    const visible = root.visibleListOf(param)
    for (let i = 0; i < visible.length; i++) {
      out.push(visible[i])
    }
    const hidden = root.hiddenListOf(param)
    for (let i = 0; i < hidden.length; i++) {
      out.push(hidden[i])
    }
    return out
  }

  function visibleListOf(param) {
    if (!param) {
      return []
    }
    if (param.type === "bool") {
      return root.boolList()
    }
    return param.list || []
  }

  function hiddenListOf(param) {
    if (!param || !param.hiddenList) {
      return []
    }
    return param.hiddenList
  }

  function boolList() {
    return [
      {
        value: "true",
        label: "true"
      },
      {
        value: "false",
        label: "false"
      }
    ]
  }

  function valueOf(item) {
    if (item !== null && typeof item === "object") {
      return String(item.value)
    }
    return String(item)
  }

  function labelOf(item) {
    if (item !== null && typeof item === "object") {
      if (item.label !== undefined) {
        return String(item.label)
      }
      if (item.name !== undefined) {
        return item.name.length > 0 ? String(item.value) + " - " + String(item.name) : String(item.value)
      }
      return String(item.value)
    }
    return String(item)
  }

  function nameOf(item) {
    if (item !== null && typeof item === "object" && item.name !== undefined) {
      return String(item.name)
    }
    return ""
  }

  function fuzzyMatch(text, query) {
    let at = 0
    for (let i = 0; i < query.length; i++) {
      const found = text.indexOf(query.charAt(i), at)
      if (found < 0) {
        return false
      }
      at = found + 1
    }
    return true
  }

  function scoreOf(item, query) {
    if (query.length === 0) {
      return 0
    }
    const value = root.valueOf(item).toLowerCase()
    const label = root.labelOf(item).toLowerCase()
    if (value === query) {
      return 1
    }
    if (value.indexOf(query) === 0) {
      return 2
    }
    if (label.indexOf(query) === 0) {
      return 3
    }
    if (root.fuzzyMatch(value, query)) {
      return 4
    }
    if (root.fuzzyMatch(label, query)) {
      return 5
    }
    return -1
  }

  function candidates(param, filter, exclude) {
    const query = String(filter === undefined || filter === null ? "" : filter).trim().toLowerCase()
    const blocked = exclude === undefined || exclude === null ? [] : exclude
    const scored = []
    const visible = root.visibleListOf(param)
    for (let i = 0; i < visible.length; i++) {
      if (root.isBlocked(visible[i], blocked)) {
        continue
      }
      const score = root.scoreOf(visible[i], query)
      if (score >= 0) {
        scored.push({
          item: visible[i],
          score: score,
          at: i
        })
      }
    }
    if (query.length >= root.hiddenMinChars) {
      const hidden = root.hiddenListOf(param)
      for (let i = 0; i < hidden.length; i++) {
        if (root.isBlocked(hidden[i], blocked)) {
          continue
        }
        const score = root.scoreOf(hidden[i], query)
        if (score >= 0) {
          scored.push({
            item: hidden[i],
            score: score,
            at: visible.length + i
          })
        }
      }
    }
    scored.sort(function (a, b) {
      if (a.score !== b.score) {
        return a.score - b.score
      }
      return a.at - b.at
    })
    const out = []
    for (let i = 0; i < scored.length; i++) {
      out.push(scored[i].item)
    }
    return out
  }

  function isBlocked(item, blocked) {
    for (let i = 0; i < blocked.length; i++) {
      if (root.valueOf(item) === blocked[i]) {
        return true
      }
    }
    return false
  }

  function matchOf(param, filter) {
    const list = root.listOf(param)
    const query = String(filter === undefined || filter === null ? "" : filter).trim().toLowerCase()
    if (query.length === 0) {
      return null
    }
    for (let i = 0; i < list.length; i++) {
      if (root.valueOf(list[i]).toLowerCase() === query) {
        return list[i]
      }
    }
    for (let i = 0; i < list.length; i++) {
      if (root.labelOf(list[i]).toLowerCase() === query) {
        return list[i]
      }
    }
    return null
  }

  function validate(param, raw) {
    const text = String(raw === undefined || raw === null ? "" : raw).trim()
    const size = param && param.size ? Number(param.size) : 0
    if (size > 0 && text.length > size) {
      return {
        ok: false,
        value: text,
        error: "max " + size + " chars"
      }
    }
    const type = param && param.type ? param.type : "string"
    if (type === "bool") {
      const low = text.toLowerCase()
      if (low === "true" || low === "1") {
        return {
          ok: true,
          value: true,
          error: ""
        }
      }
      if (low === "false" || low === "0") {
        return {
          ok: true,
          value: false,
          error: ""
        }
      }
      return {
        ok: false,
        value: text,
        error: "true or false"
      }
    }
    if (type === "int" || type === "float") {
      if (!/^[+-]?(\d+(\.\d*)?|\.\d+)$/.test(text)) {
        return {
          ok: false,
          value: text,
          error: type === "int" ? "whole number" : "number"
        }
      }
      const num = Number(text)
      if (param.min !== undefined && num < Number(param.min)) {
        return {
          ok: false,
          value: num,
          error: "min " + String(param.min)
        }
      }
      if (param.max !== undefined && num > Number(param.max)) {
        return {
          ok: false,
          value: num,
          error: "max " + String(param.max)
        }
      }
      return {
        ok: true,
        value: type === "int" ? Math.round(num) : num,
        error: ""
      }
    }
    if (type === "enum") {
      const matched = root.matchOf(param, text)
      if (!matched) {
        return {
          ok: false,
          value: text,
          error: "unknown value"
        }
      }
      return {
        ok: true,
        value: root.valueOf(matched),
        error: ""
      }
    }
    return {
      ok: true,
      value: text,
      error: ""
    }
  }
}
