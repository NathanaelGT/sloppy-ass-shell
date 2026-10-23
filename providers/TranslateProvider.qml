pragma Singleton
import Quickshell
import "../theme"

Singleton {
  id: root

  readonly property string key: "tr"
  readonly property string name: "Translate"
  readonly property string desc: "Translate words and sentences"
  readonly property url logo: "../assets/google-translate.svg"
  readonly property var params: [
    {
      key: "from",
      label: "from",
      type: "enum",
      required: false,
      default: "auto",
      list: root.sourceLanguages,
      hiddenList: root.otherLanguages,
      size: 5,
      desc: "source language",
      codeWidth: 2,
      distinct: ["to"]
    },
    {
      key: "to",
      label: "to",
      type: "enum",
      required: true,
      list: root.targetLanguages,
      hiddenList: root.otherLanguages,
      size: 5,
      desc: "target language",
      codeWidth: 2,
      distinct: ["from"]
    }
  ]
  readonly property string errorText: "Translation failed"

  readonly property var sourceLanguages: [
    {
      value: "auto",
      name: ""
    },
    {
      value: "en",
      name: "English"
    },
    {
      value: "id",
      name: "Bahasa Indonesia"
    },
    {
      value: "ja",
      name: "Nihongo"
    }
  ]

  readonly property var targetLanguages: [
    {
      value: "en",
      name: "English"
    },
    {
      value: "id",
      name: "Bahasa Indonesia"
    },
    {
      value: "ja",
      name: "Nihongo"
    }
  ]

  readonly property var otherLanguages: [
    {
      value: "af",
      name: "Afrikaans"
    },
    {
      value: "sq",
      name: "Albanian"
    },
    {
      value: "am",
      name: "Amharic"
    },
    {
      value: "ar",
      name: "Al-Arabiyah"
    },
    {
      value: "hy",
      name: "Armenian"
    },
    {
      value: "az",
      name: "Azerbaijani"
    },
    {
      value: "eu",
      name: "Basque"
    },
    {
      value: "be",
      name: "Belarusian"
    },
    {
      value: "bn",
      name: "Bengali"
    },
    {
      value: "bs",
      name: "Bosnian"
    },
    {
      value: "bg",
      name: "Bulgarian"
    },
    {
      value: "ca",
      name: "Catalan"
    },
    {
      value: "ceb",
      name: "Cebuano"
    },
    {
      value: "ny",
      name: "Chichewa"
    },
    {
      value: "zh",
      name: "Zhongwen"
    },
    {
      value: "zh-tw",
      name: "Zhongwen Tradisional"
    },
    {
      value: "co",
      name: "Corsican"
    },
    {
      value: "hr",
      name: "Croatian"
    },
    {
      value: "cs",
      name: "Cestina"
    },
    {
      value: "da",
      name: "Dansk"
    },
    {
      value: "nl",
      name: "Nederlands"
    },
    {
      value: "eo",
      name: "Esperanto"
    },
    {
      value: "et",
      name: "Estonian"
    },
    {
      value: "tl",
      name: "Filipino"
    },
    {
      value: "fi",
      name: "Suomi"
    },
    {
      value: "fr",
      name: "Francais"
    },
    {
      value: "fy",
      name: "Frisian"
    },
    {
      value: "gl",
      name: "Galician"
    },
    {
      value: "ka",
      name: "Georgian"
    },
    {
      value: "de",
      name: "Deutsch"
    },
    {
      value: "el",
      name: "Ellinika"
    },
    {
      value: "gu",
      name: "Gujarati"
    },
    {
      value: "ht",
      name: "Haitian Creole"
    },
    {
      value: "ha",
      name: "Hausa"
    },
    {
      value: "haw",
      name: "Hawaiian Creole"
    },
    {
      value: "he",
      name: "Ivrit"
    },
    {
      value: "hi",
      name: "Hindī"
    },
    {
      value: "hmn",
      name: "Hmong"
    },
    {
      value: "hu",
      name: "Magyar"
    },
    {
      value: "is",
      name: "Icelandic"
    },
    {
      value: "ig",
      name: "Igbo"
    },
    {
      value: "ga",
      name: "Irish"
    },
    {
      value: "it",
      name: "Italiano"
    },
    {
      value: "jv",
      name: "Javanese"
    },
    {
      value: "kn",
      name: "Kannada"
    },
    {
      value: "kk",
      name: "Kazakh"
    },
    {
      value: "km",
      name: "Khmer"
    },
    {
      value: "ko",
      name: "Hangugeo"
    },
    {
      value: "ku",
      name: "Kurdish"
    },
    {
      value: "ky",
      name: "Kyrgyz"
    },
    {
      value: "lo",
      name: "Lao"
    },
    {
      value: "la",
      name: "Latin"
    },
    {
      value: "lv",
      name: "Latvian"
    },
    {
      value: "lt",
      name: "Lithuanian"
    },
    {
      value: "lb",
      name: "Luxembourgish"
    },
    {
      value: "mk",
      name: "Macedonian"
    },
    {
      value: "mg",
      name: "Malagasy"
    },
    {
      value: "ms",
      name: "Bahasa Melayu"
    },
    {
      value: "ml",
      name: "Malayalam"
    },
    {
      value: "mt",
      name: "Maltese"
    },
    {
      value: "mi",
      name: "Maori"
    },
    {
      value: "mr",
      name: "Marathi"
    },
    {
      value: "mn",
      name: "Mongolian"
    },
    {
      value: "my",
      name: "Burmese"
    },
    {
      value: "ne",
      name: "Nepali"
    },
    {
      value: "nb",
      name: "Norsk bokmal"
    },
    {
      value: "ps",
      name: "Pashto"
    },
    {
      value: "fa",
      name: "Persian"
    },
    {
      value: "pl",
      name: "Polski"
    },
    {
      value: "pt",
      name: "Portugues"
    },
    {
      value: "pa",
      name: "Punjabi"
    },
    {
      value: "ro",
      name: "Romana"
    },
    {
      value: "ru",
      name: "Russkij"
    },
    {
      value: "sm",
      name: "Samoan"
    },
    {
      value: "gd",
      name: "Scots Gaelic"
    },
    {
      value: "sr",
      name: "Serbian"
    },
    {
      value: "st",
      name: "Sesotho"
    },
    {
      value: "sn",
      name: "Shona"
    },
    {
      value: "sd",
      name: "Sindhi"
    },
    {
      value: "si",
      name: "Sinhala"
    },
    {
      value: "sk",
      name: "Slovak"
    },
    {
      value: "sl",
      name: "Slovenian"
    },
    {
      value: "so",
      name: "Somali"
    },
    {
      value: "es",
      name: "Espanol"
    },
    {
      value: "su",
      name: "Sundanese"
    },
    {
      value: "sw",
      name: "Swahili"
    },
    {
      value: "sv",
      name: "Svenska"
    },
    {
      value: "tg",
      name: "Tajik"
    },
    {
      value: "ta",
      name: "Tamil"
    },
    {
      value: "te",
      name: "Telugu"
    },
    {
      value: "th",
      name: "Thai"
    },
    {
      value: "tr",
      name: "Turkce"
    },
    {
      value: "tk",
      name: "Turkmen"
    },
    {
      value: "tt",
      name: "Tatar"
    },
    {
      value: "uk",
      name: "Ukrainska"
    },
    {
      value: "ur",
      name: "Urdu"
    },
    {
      value: "ug",
      name: "Uyghur"
    },
    {
      value: "uz",
      name: "Uzbek"
    },
    {
      value: "vi",
      name: "Tieng Viet"
    },
    {
      value: "cy",
      name: "Welsh"
    },
    {
      value: "xh",
      name: "Xhosa"
    },
    {
      value: "yi",
      name: "Yiddish"
    },
    {
      value: "yo",
      name: "Yoruba"
    },
    {
      value: "zu",
      name: "Zulu"
    },
    {
      value: "br",
      name: "Breton"
    },
    {
      value: "gom",
      name: "Goan Konkani"
    },
    {
      value: "kok",
      name: "Konkani"
    },
    {
      value: "mai",
      name: "Maithili"
    },
    {
      value: "oc",
      name: "Occitan"
    },
    {
      value: "sat",
      name: "Santali"
    },
    {
      value: "ay",
      name: "Aymara"
    },
    {
      value: "bho",
      name: "Bhojpuri"
    },
    {
      value: "bm",
      name: "Bambara"
    },
    {
      value: "bo",
      name: "Tibetan"
    },
    {
      value: "doi",
      name: "Dogri"
    },
    {
      value: "dz",
      name: "Dzongkha"
    },
    {
      value: "ee",
      name: "Ewe"
    },
    {
      value: "ff",
      name: "Fulah"
    },
    {
      value: "gn",
      name: "Guarani"
    },
    {
      value: "kg",
      name: "Kongo"
    },
    {
      value: "lg",
      name: "Ganda"
    },
    {
      value: "lua",
      name: "Luba-Katanga"
    },
    {
      value: "mhr",
      name: "Mari"
    },
    {
      value: "mwr",
      name: "Marwari"
    },
    {
      value: "nso",
      name: "Northern Sotho"
    },
    {
      value: "om",
      name: "Oromo"
    },
    {
      value: "qu",
      name: "Quechua"
    },
    {
      value: "sah",
      name: "Yakut"
    },
    {
      value: "ss",
      name: "Swati"
    },
    {
      value: "ti",
      name: "Tigrinya"
    },
    {
      value: "tn",
      name: "Tswana"
    },
    {
      value: "tw",
      name: "Twi"
    },
    {
      value: "ve",
      name: "Venda"
    },
    {
      value: "wo",
      name: "Wolof"
    }
  ]

  function buildUrl(ctx) {
    return "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" + ctx.values.from + "&tl=" + ctx.values.to + "&dt=t&q=" + encodeURIComponent(ctx.term)
  }

  function requestArgs(url) {
    return ["curl", "-s", "--max-time", "10", "-A", "Mozilla/5.0", "--http1.1", "--tls-max", "1.2", url]
  }

  function parse(text) {
    let data = null
    try {
      data = JSON.parse(text)
    } catch (e) {
      data = null
    }
    const translation = root.mapTranslation(data)
    if (translation.length === 0) {
      return {
        results: [],
        error: root.errorText
      }
    }
    return {
      results: [translation],
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
    if (data && typeof data.translation === "string") {
      data = data.translation
    }
    const translation = root.mapTranslation(data)
    if (translation.length === 0) {
      return {
        results: [],
        error: root.errorText
      }
    }
    return {
      results: [translation],
      error: ""
    }
  }

  function rows(ctx) {
    if (ctx.error.length > 0) {
      return [root.errorRow()]
    }
    const results = ctx.results || []
    if (results.length === 0) {
      return []
    }
    return [
      {
        key: "tr:0",
        title: results[0],
        titleRich: false,
        titleColor: Theme.text,
        subtitle: ctx.term,
        subtitleRich: false,
        subtitleColor: Theme.overlay,
        glyph: "world",
        image: "",
        badge: "",
        badgeColor: Theme.surfaceHigh,
        action: "copy",
        copyText: results[0]
      }
    ]
  }

  function cardTitle(ctx) {
    if (ctx.state === "loading") {
      return "Translating..."
    }
    if (ctx.state === "search") {
      return "Translate \"" + ctx.term + "\""
    }
    return root.name
  }

  function cardHint(ctx) {
    if (ctx.state === "loading") {
      return ctx.term
    }
    if (ctx.state === "search") {
      return "Press Enter to translate (" + ctx.values.from + " → " + ctx.values.to + ")"
    }
    return "Type a phrase · Tab to change the language"
  }

  function errorRow() {
    return {
      key: "tr:error",
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

  function mapTranslation(data) {
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
}
