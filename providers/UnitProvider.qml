pragma Singleton
import Quickshell
import "../theme"

Singleton {
  id: root

  readonly property string key: "unit"
  readonly property string name: "Units"
  readonly property string desc: "Convert length, weight, temperature, volume, time and data size"
  readonly property url logo: "../assets/unit.svg"
  readonly property var params: []
  readonly property string errorText: "Conversion failed"
  readonly property bool local: true
  readonly property bool listOnEmpty: true

  readonly property var categories: [
    {
      id: "length",
      color: Theme.primary,
      units: [
        {
          s: "m",
          n: "Meter",
          f: 1,
          a: ["metre", "metres"]
        },
        {
          s: "km",
          n: "Kilometer",
          f: 1000,
          a: ["kilometre", "kilometres"]
        },
        {
          s: "dm",
          n: "Decimeter",
          f: 0.1,
          a: ["decimetre", "decimetres"]
        },
        {
          s: "cm",
          n: "Centimeter",
          f: 0.01,
          a: ["centimetre", "centimetres"]
        },
        {
          s: "mm",
          n: "Millimeter",
          f: 0.001,
          a: ["millimetre", "millimetres"]
        },
        {
          s: "µm",
          n: "Micrometer",
          f: 0.000001,
          a: ["micrometre", "micrometres", "micron", "microns"]
        },
        {
          s: "nm",
          n: "Nanometer",
          f: 0.000000001,
          a: ["nanometre", "nanometres"]
        },
        {
          s: "mi",
          n: "Mile",
          f: 1609.344,
          a: ["miles"]
        },
        {
          s: "yd",
          n: "Yard",
          f: 0.9144,
          a: ["yards"]
        },
        {
          s: "ft",
          n: "Foot",
          f: 0.3048,
          a: ["feet"]
        },
        {
          s: "in",
          n: "Inch",
          f: 0.0254,
          a: ["inches"]
        },
        {
          s: "nmi",
          n: "Nautical Mile",
          f: 1852,
          a: ["nmile"]
        }
      ]
    },
    {
      id: "weight",
      color: Theme.green,
      units: [
        {
          s: "t",
          n: "Tonne",
          f: 1000,
          a: ["tonne", "tonnes", "ton", "tons", "metric ton"]
        },
        {
          s: "kg",
          n: "Kilogram",
          f: 1,
          a: ["kilo", "kilos"]
        },
        {
          s: "g",
          n: "Gram",
          f: 0.001,
          a: ["gramme", "grammes"]
        },
        {
          s: "mg",
          n: "Milligram",
          f: 0.000001,
          a: ["milligramme", "milligrammes"]
        },
        {
          s: "st",
          n: "Stone",
          f: 6.35029318,
          a: ["stones"]
        },
        {
          s: "lb",
          n: "Pound",
          f: 0.45359237,
          a: ["lbs"]
        },
        {
          s: "oz",
          n: "Ounce",
          f: 0.028349523125,
          a: ["ounces"]
        }
      ]
    },
    {
      id: "temperature",
      color: Theme.red,
      units: [
        {
          s: "°C",
          n: "Celsius",
          f: 1,
          o: 0,
          a: ["centigrade", "degc"]
        },
        {
          s: "°F",
          n: "Fahrenheit",
          f: 0.5555555555555556,
          o: -32,
          a: ["degf"]
        },
        {
          s: "K",
          n: "Kelvin",
          f: 1,
          o: -273.15,
          a: ["degk"]
        },
        {
          s: "°R",
          n: "Rankine",
          f: 0.5555555555555556,
          o: -491.67,
          a: ["degr"]
        }
      ]
    },
    {
      id: "volume",
      color: Theme.yellow,
      units: [
        {
          s: "m³",
          n: "Cubic Meter",
          f: 1000,
          a: ["cubic metre", "cubic metres"]
        },
        {
          s: "L",
          n: "Liter",
          f: 1,
          a: ["litre", "litres"]
        },
        {
          s: "mL",
          n: "Milliliter",
          f: 0.001,
          a: ["millilitre", "millilitres"]
        },
        {
          s: "cm³",
          n: "Cubic Centimeter",
          f: 0.001,
          a: ["cubic centimetre", "cubic centimetres", "cc", "ccm"]
        },
        {
          s: "ft³",
          n: "Cubic Foot",
          f: 28.316846592,
          a: ["cubic foot", "cubic feet"]
        },
        {
          s: "in³",
          n: "Cubic Inch",
          f: 0.016387064,
          a: ["cubic inch", "cubic inches"]
        },
        {
          s: "gal",
          n: "Gallon",
          f: 3.785411784,
          a: ["gallons"]
        },
        {
          s: "qt",
          n: "Quart",
          f: 0.946352946,
          a: ["quarts"]
        },
        {
          s: "pt",
          n: "Pint",
          f: 0.473176473,
          a: ["pints"]
        },
        {
          s: "cup",
          n: "Cup",
          f: 0.2365882365,
          a: ["cups"]
        },
        {
          s: "floz",
          n: "Fluid Ounce",
          f: 0.0295735295625,
          a: ["fluid ounce", "fluid ounces", "fl oz", "fl. oz.", "fluz"]
        },
        {
          s: "tbsp",
          n: "Tablespoon",
          f: 0.01478676478125,
          b: "tb",
          a: ["tablespoon", "tablespoons"]
        },
        {
          s: "tsp",
          n: "Teaspoon",
          f: 0.00492892159375,
          a: ["teaspoon", "teaspoons"]
        }
      ]
    },
    {
      id: "time",
      color: Qt.color("#cba6f7"),
      units: [
        {
          s: "yr",
          n: "Year",
          f: 31557600,
          a: ["years"]
        },
        {
          s: "mo",
          n: "Month",
          f: 2629800,
          a: ["months"]
        },
        {
          s: "wk",
          n: "Week",
          f: 604800,
          a: ["weeks"]
        },
        {
          s: "d",
          n: "Day",
          f: 86400,
          a: ["days"]
        },
        {
          s: "h",
          n: "Hour",
          f: 3600,
          a: ["hr", "hrs", "hour", "hours"]
        },
        {
          s: "min",
          n: "Minute",
          f: 60,
          a: ["mins", "minute", "minutes"]
        },
        {
          s: "s",
          n: "Second",
          f: 1,
          a: ["sec", "secs", "second", "seconds"]
        },
        {
          s: "ms",
          n: "Millisecond",
          f: 0.001,
          a: ["milliseconds"]
        },
        {
          s: "µs",
          n: "Microsecond",
          f: 0.000001,
          a: ["microseconds"]
        },
        {
          s: "ns",
          n: "Nanosecond",
          f: 0.000000001,
          a: ["nanoseconds"]
        }
      ]
    },
    {
      id: "data",
      color: Qt.color("#94e2d5"),
      kind: "data",
      bytes: {
        s: "B",
        n: "Byte",
        f: 1,
        a: ["bytes"]
      },
      tiers: [
        {
          kibi: {
            s: "KiB",
            n: "Kibibyte",
            f: 1024,
            a: ["kibibytes"]
          },
          kilo: {
            s: "kB",
            n: "Kilobyte",
            f: 1000,
            a: ["kilobytes"]
          }
        },
        {
          kibi: {
            s: "MiB",
            n: "Mebibyte",
            f: 1048576,
            a: ["mebibytes"]
          },
          kilo: {
            s: "MB",
            n: "Megabyte",
            f: 1000000,
            a: ["megabytes"]
          }
        },
        {
          kibi: {
            s: "GiB",
            n: "Gibibyte",
            f: 1073741824,
            a: ["gibibytes"]
          },
          kilo: {
            s: "GB",
            n: "Gigabyte",
            f: 1000000000,
            a: ["gigabytes"]
          }
        },
        {
          kibi: {
            s: "TiB",
            n: "Tebibyte",
            f: 1099511627776,
            a: ["tebibytes"]
          },
          kilo: {
            s: "TB",
            n: "Terabyte",
            f: 1000000000000,
            a: ["terabytes"]
          }
        }
      ]
    }
  ]

  function symbolKey(text) {
    return String(text === undefined || text === null ? "" : text).replace(/[\s ]/g, "").replace(/°/g, "").replace(/³/g, "3").replace(/²/g, "2").replace(/µ/g, "u").replace(/μ/g, "u")
  }

  function foldKey(text) {
    return root.symbolKey(text).toLowerCase()
  }

  function pluralize(word) {
    if (/(ch|sh|ss|x|z)$/.test(word)) {
      return word + "es"
    }
    if (/[^aeiou]y$/.test(word)) {
      return word.slice(0, -1) + "ies"
    }
    return word + "s"
  }

  function aliasesOf(unit) {
    const out = []
    out.push(unit.s)
    if (unit.n) {
      out.push(unit.n)
      const words = unit.n.split(" ")
      words[words.length - 1] = root.pluralize(words[words.length - 1])
      out.push(words.join(" "))
    }
    if (unit.a) {
      for (let i = 0; i < unit.a.length; i++) {
        out.push(unit.a[i])
      }
    }
    return out
  }

  function unitsOf(cat) {
    const out = []
    if (cat.units) {
      for (let i = 0; i < cat.units.length; i++) {
        out.push(cat.units[i])
      }
    }
    if (cat.bytes) {
      out.push(cat.bytes)
    }
    if (cat.tiers) {
      for (let i = 0; i < cat.tiers.length; i++) {
        out.push(cat.tiers[i].kibi)
        out.push(cat.tiers[i].kilo)
      }
    }
    return out
  }

  function findUnit(text) {
    const symbol = root.symbolKey(text)
    for (let c = 0; c < root.categories.length; c++) {
      const cat = root.categories[c]
      const units = root.unitsOf(cat)
      for (let u = 0; u < units.length; u++) {
        if (root.symbolKey(units[u].s) === symbol) {
          return {
            cat: cat,
            unit: units[u]
          }
        }
      }
    }
    const folded = root.foldKey(text)
    for (let c = 0; c < root.categories.length; c++) {
      const cat = root.categories[c]
      const units = root.unitsOf(cat)
      for (let u = 0; u < units.length; u++) {
        const aliases = root.aliasesOf(units[u])
        for (let i = 0; i < aliases.length; i++) {
          if (root.foldKey(aliases[i]) === folded) {
            return {
              cat: cat,
              unit: units[u]
            }
          }
        }
      }
    }
    return null
  }

  function parseTerm(term) {
    const match = term.match(/^([+-]?(?:\d+(?:[.,]\d+)?|[.,]\d+))?\s*(.*)$/)
    if (!match) {
      return {
        ok: false,
        message: "Could not read \"" + term + "\""
      }
    }
    const numberText = match[1]
    const unitText = match[2].trim()
    if (unitText.length === 0) {
      return {
        ok: false,
        message: "Add a unit, for example 5 km"
      }
    }
    const amount = numberText === undefined ? 1 : Number(numberText.replace(",", "."))
    if (!isFinite(amount)) {
      return {
        ok: false,
        message: "Could not read the amount in \"" + term + "\""
      }
    }
    const hit = root.findUnit(unitText)
    if (!hit) {
      return {
        ok: false,
        message: "Unknown unit \"" + unitText + "\""
      }
    }
    const offset = hit.unit.o === undefined ? 0 : hit.unit.o
    return {
      ok: true,
      amount: amount,
      cat: hit.cat,
      unit: hit.unit,
      base: (amount + offset) * hit.unit.f
    }
  }

  function trimExponential(text) {
    return String(text).replace(/(\.\d*?)0+e/, "$1e").replace(/\.e/, "e")
  }

  function trimZeros(text) {
    return String(text).replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")
  }

  function formatValue(value) {
    if (!isFinite(value)) {
      return "-"
    }
    if (value === 0) {
      return "0"
    }
    const abs = Math.abs(value)
    if (abs >= 1e15) {
      return root.trimExponential(value.toExponential(6))
    }
    const rounded = Math.round(value)
    if (Math.abs(value - rounded) <= abs * 1e-12) {
      return String(rounded)
    }
    if (abs >= 0.0001) {
      return String(Number(value.toPrecision(6)))
    }
    const plain = root.trimZeros(value.toFixed(12))
    if (plain.length <= 14 && Number(plain) !== 0) {
      return plain
    }
    return root.trimExponential(value.toExponential(5))
  }

  function richTitle(value, label) {
    return "<font color=\"" + Colors.hex(Theme.text) + "\">" + value + "</font> <font color=\"" + Colors.hex(Theme.overlay) + "\">" + label + "</font>"
  }

  function linearResults(parsed) {
    const out = []
    const units = parsed.cat.units
    for (let i = 0; i < units.length; i++) {
      const unit = units[i]
      if (unit.s === parsed.unit.s) {
        continue
      }
      const offset = unit.o === undefined ? 0 : unit.o
      const text = root.formatValue(parsed.base / unit.f - offset)
      out.push({
        key: parsed.cat.id + ":" + unit.s,
        value: text,
        label: unit.n,
        sub: "",
        badge: unit.b === undefined ? unit.s : unit.b,
        glyph: "",
        copy: text + " " + unit.s,
        color: parsed.cat.color
      })
    }
    return out
  }

  function dataResults(parsed) {
    const out = []
    const tiers = parsed.cat.tiers
    for (let i = 0; i < tiers.length; i++) {
      const tier = tiers[i]
      const kibi = root.formatValue(parsed.base / tier.kibi.f)
      const kilo = root.formatValue(parsed.base / tier.kilo.f)
      out.push({
        key: parsed.cat.id + ":" + tier.kibi.s,
        value: kibi,
        label: tier.kibi.s,
        sub: kilo + " " + tier.kilo.s,
        badge: "",
        glyph: "stack",
        copy: kibi + " " + tier.kibi.s,
        color: parsed.cat.color
      })
    }
    return out
  }

  function parse(text) {
    const term = String(text === undefined || text === null ? "" : text).trim()
    if (term.length === 0) {
      return {
        results: [],
        error: ""
      }
    }
    const parsed = root.parseTerm(term)
    if (!parsed.ok) {
      return {
        results: [],
        error: parsed.message
      }
    }
    if (parsed.cat.kind === "data") {
      return {
        results: root.dataResults(parsed),
        error: ""
      }
    }
    return {
      results: root.linearResults(parsed),
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
    if (String(ctx.term === undefined || ctx.term === null ? "" : ctx.term).trim().length === 0) {
      const out = []
      for (let c = 0; c < root.categories.length; c++) {
        const cat = root.categories[c]
        const units = root.unitsOf(cat)
        const symbols = []
        for (let u = 0; u < units.length; u++) {
          symbols.push(units[u].s)
        }
        const name = String(cat.id).charAt(0).toUpperCase() + String(cat.id).slice(1)
        out.push({
          key: "unit:category:" + cat.id,
          title: name,
          titleRich: false,
          titleColor: cat.color,
          subtitle: symbols.join("  "),
          subtitleRich: false,
          subtitleColor: Theme.subtext,
          glyph: "",
          image: "",
          badge: String(units.length),
          badgeColor: cat.color,
          action: "",
          copyText: ""
        })
      }
      return out
    }
    const out = []
    const results = ctx.results || []
    for (let i = 0; i < results.length; i++) {
      const item = results[i]
      out.push({
        key: "unit:" + item.key,
        title: root.richTitle(item.value, item.label),
        titleRich: true,
        titleColor: Theme.text,
        subtitle: item.sub,
        subtitleRich: false,
        subtitleColor: Theme.subtext,
        glyph: item.glyph,
        image: "",
        badge: item.badge,
        badgeColor: item.color,
        action: "copy",
        copyText: item.copy
      })
    }
    return out
  }

  function errorRow(message) {
    return {
      key: "unit:error",
      title: String(message),
      titleRich: false,
      titleColor: Theme.text,
      subtitle: "Type a value and a unit, for example 5 km",
      subtitleRich: false,
      subtitleColor: Theme.overlay,
      glyph: "search",
      image: "",
      badge: "",
      badgeColor: Theme.surfaceHigh,
      action: "",
      copyText: ""
    }
  }

  function cardTitle(ctx) {
    return root.name
  }

  function cardHint(ctx) {
    return "Type @" + root.key + " 5 km to convert"
  }
}
