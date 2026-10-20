pragma Singleton
import Quickshell

Singleton {
  id: root

  readonly property url onelookLogo: "../assets/onelook.svg"
  readonly property url translateLogo: "../assets/google-translate.svg"

  readonly property var languages: [
    {
      value: "auto",
      label: "auto"
    },
    {
      value: "en",
      label: "en - English"
    },
    {
      value: "id",
      label: "id - Bahasa Indonesia"
    },
    {
      value: "ms",
      label: "ms - Bahasa Melayu"
    },
    {
      value: "de",
      label: "de - Deutsch"
    },
    {
      value: "fr",
      label: "fr - Francais"
    },
    {
      value: "es",
      label: "es - Espanol"
    },
    {
      value: "it",
      label: "it - Italiano"
    },
    {
      value: "pt",
      label: "pt - Portugues"
    },
    {
      value: "nl",
      label: "nl - Nederlands"
    },
    {
      value: "ru",
      label: "ru - Russkij"
    },
    {
      value: "uk",
      label: "uk - Ukrainska"
    },
    {
      value: "ja",
      label: "ja - Nihongo"
    },
    {
      value: "ko",
      label: "ko - Hangugeo"
    },
    {
      value: "zh",
      label: "zh - Zhongwen"
    },
    {
      value: "ar",
      label: "ar - Al-Arabiyah"
    },
    {
      value: "hi",
      label: "hi - Hindī"
    },
    {
      value: "th",
      label: "th - Thai"
    },
    {
      value: "vi",
      label: "vi - Tieng Viet"
    },
    {
      value: "tr",
      label: "tr - Turkce"
    },
    {
      value: "pl",
      label: "pl - Polski"
    },
    {
      value: "sv",
      label: "sv - Svenska"
    },
    {
      value: "da",
      label: "da - Dansk"
    },
    {
      value: "fi",
      label: "fi - Suomi"
    },
    {
      value: "nb",
      label: "nb - Norsk bokmal"
    },
    {
      value: "cs",
      label: "cs - Cestina"
    },
    {
      value: "el",
      label: "el - Ellinika"
    },
    {
      value: "he",
      label: "he - Ivrit"
    },
    {
      value: "hu",
      label: "hu - Magyar"
    },
    {
      value: "ro",
      label: "ro - Romana"
    }
  ]

  readonly property var providers: [
    {
      key: "ol",
      name: "OneLook",
      desc: "Find English definition and related words",
      logo: root.onelookLogo,
      params: []
    },
    {
      key: "tr",
      name: "Translate",
      desc: "Translate words and sentences",
      logo: root.translateLogo,
      params: [
        {
          key: "from",
          label: "from",
          type: "enum",
          required: false,
          default: "auto",
          list: root.languages,
          size: 5,
          desc: "source language"
        },
        {
          key: "to",
          label: "to",
          type: "enum",
          required: true,
          list: root.languages,
          size: 5,
          desc: "target language"
        }
      ]
    }
  ]

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

  function listOf(param) {
    if (!param) {
      return []
    }
    if (param.type === "bool") {
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
    return param.list || []
  }

  function valueOf(item) {
    if (item !== null && typeof item === "object") {
      return String(item.value)
    }
    return String(item)
  }

  function labelOf(item) {
    if (item !== null && typeof item === "object") {
      return item.label === undefined ? String(item.value) : String(item.label)
    }
    return String(item)
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

  function candidates(param, filter) {
    const list = root.listOf(param)
    const query = String(filter === undefined || filter === null ? "" : filter).trim().toLowerCase()
    const scored = []
    for (let i = 0; i < list.length; i++) {
      const score = root.scoreOf(list[i], query)
      if (score >= 0) {
        scored.push({
          item: list[i],
          score: score,
          at: i
        })
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
