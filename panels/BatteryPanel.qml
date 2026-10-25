import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../components"
import "../services"

PanelBase {
  id: root

  panelName: "battery"
  cardWidth: Theme.panelWidth * 2
  popupOpen: procMenu.opened

  property real cpuUsage: 0
  property real cpuTemp: 0
  property real cpuWatt: 0
  property real cpuClock: 0
  property string cpuName: ""
  property var cpuCores: []
  property int cpuThreads: 0
  property real memUsed: 0
  property real memTotal: 0
  property real zramUsed: 0
  property real zswapPool: 0
  property real swapfileUsed: 0
  property int spdType: 0
  property int spdTck: 0
  property real gpuUsage: 0
  property real gpuTemp: 0
  property real gpuWatt: 0
  property string gpuClock: ""
  property string gpuName: ""
  property real gpuVramUsed: 0
  property real gpuVramTotal: 0
  property real igpuUsage: 0
  property real igpuTemp: 0
  property real igpuWatt: 0
  property real igpuClock: 0
  property real igpuVramUsed: 0
  property real igpuVramTotal: 0
  property string igpuName: ""

  property var procRaw: []
  property var procGpu: ({})
  property var procPrev: ({})
  property var procExpanded: ({})
  property var procMetaCache: ({})
  property var procGames: ({})
  property double procTs: 0
  property string procSort: "mem"
  property bool procAsc: false
  property string procFilter: ""
  readonly property var procAvatarPalette: [Theme.primary, Theme.mauve, Theme.teal, Theme.green, Theme.yellow, Theme.red]
  readonly property var procIconAliases: ({
      hyprland: "file://" + Quickshell.env("HOME") + "/.local/share/icons/Wallbash-Icon/distro/hyprland.png",
      quickshell: "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/scalable/apps/org.quickshell.svg"
    })
  readonly property var procNameAliases: ({
      quickshell: "Quickshell"
    })
  property int procNcpu: 1
  property string procMenuKind: ""
  property int procMenuKey: 0
  property string procMenuName: ""
  property bool procMenuStopped: false
  readonly property int procMax: 40
  readonly property var procCols: [
    {
      key: "cpu",
      label: "CPU",
      w: 46
    },
    {
      key: "mem",
      label: "Mem",
      w: 60
    },
    {
      key: "disk",
      label: "Disk",
      w: 76
    },
    {
      key: "net",
      label: "Net",
      w: 76
    },
    {
      key: "dgpu",
      label: "dGPU",
      w: 88
    },
    {
      key: "igpu",
      label: "iGPU",
      w: 88
    }
  ]
  readonly property var procTarget: buildProcDisplay()
  animateCardHeight: true

  function rowToModel(r) {
    return {
      kind: r.kind,
      key: r.key,
      name: r.name,
      icon: r.icon !== undefined ? r.icon : "",
      letter: r.letter !== undefined ? r.letter : "",
      accent: r.accent !== undefined ? r.accent : Theme.primary,
      count: r.count !== undefined ? r.count : 1,
      expanded: r.expanded === true,
      cpu: r.cpu,
      mem: r.mem,
      disk: r.disk,
      net: r.net,
      dgpu: r.dgpu,
      dvram: r.dvram,
      igpu: r.igpu,
      ivram: r.ivram
    }
  }

  function syncProcModel() {
    const target = root.procTarget
    const order = []
    for (let i = 0; i < procModel.count; i++) {
      const it = procModel.get(i)
      order.push(it.kind + ":" + it.key)
    }
    const wanted = {}
    for (let i = 0; i < target.length; i++) {
      wanted[target[i].kind + ":" + target[i].key] = true
    }
    for (let i = order.length - 1; i >= 0; i--) {
      if (!wanted[order[i]]) {
        procModel.remove(i, 1)
        order.splice(i, 1)
      }
    }
    const present = {}
    for (const k of order) {
      present[k] = true
    }
    for (let i = 0; i < target.length; i++) {
      const k = target[i].kind + ":" + target[i].key
      if (!present[k]) {
        procModel.insert(i, rowToModel(target[i]))
        order.splice(i, 0, k)
        present[k] = true
      } else if (order[i] !== k) {
        const j = order.indexOf(k)
        procModel.move(j, i, 1)
        order.splice(j, 1)
        order.splice(i, 0, k)
      }
    }
    for (let i = 0; i < target.length; i++) {
      procModel.set(i, rowToModel(target[i]))
    }
  }

  onProcTargetChanged: root.syncProcModel()

  readonly property int animMs: 500
  property bool primed: false
  readonly property int memSpeed: {
    if (root.spdTck <= 0) {
      return 0
    }
    const mhz = Math.round(2000000 / root.spdTck)
    const stds = [1600, 1866, 2133, 2400, 2600, 2800, 2933, 3200, 3600, 4000, 4400, 4800, 5200, 5600, 6000, 6400, 6800, 7200, 7600, 8000, 8533, 9600]
    let best = 0
    let dist = Infinity
    for (let i = 0; i < stds.length; i++) {
      const d = Math.abs(stds[i] - mhz)
      if (d < dist) {
        dist = d
        best = stds[i]
      }
    }
    return best
  }

  function collectScript() {
    return ["c1=$(grep '^cpu ' /proc/stat)", "p1=$(grep '^cpu[0-9]' /proc/stat)", "sleep 0.2", "c2=$(grep '^cpu ' /proc/stat)", "p2=$(grep '^cpu[0-9]' /proc/stat)", "set -- $c1; u1=$2; n1=$3; s1=$4; i1=$5; io1=$6; irq1=$7; si1=$8; st1=$9", "set -- $c2; u2=$2; n2=$3; s2=$4; i2=$5; io2=$6; irq2=$7; si2=$8; st2=$9", "total1=$((u1+n1+s1+i1+io1+irq1+si1+st1))", "total2=$((u2+n2+s2+i2+io2+irq2+si2+st2))", "idle1=$((i1+io1))", "idle2=$((i2+io2))", "core_pcts=$(paste <(echo \"$p1\") <(echo \"$p2\") | awk '{a=$2+$3+$4+$7+$8+$9; b=$5+$6; ta=a+b; c=$13+$14+$15+$18+$19+$20; d=$16+$17; tc=c+d; dt=tc-ta; di=d-b; v=(dt>0)?(dt-di)/dt*100:0; printf \"%s%.1f\", (NR>1?\" \":\"\"), v}')", "cpu_threads=$(nproc)", "cpu_usage=$(awk -v t1=$total1 -v t2=$total2 -v i1=$idle1 -v i2=$idle2 'BEGIN{dt=t2-t1; di=i2-i1; if(dt>0) printf \"%.1f\", (dt-di)/dt*100; else print 0}')", "cpu_watt=$(cat /run/cpu-watt 2>/dev/null || echo 0)", "cpu_temp=$(awk '{printf \"%.1f\", $1/1000}' /sys/class/hwmon/hwmon4/temp1_input)", "cpu_name=$(grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2 | sed 's/^ *//')", "cpu_clock=$(awk '/^cpu MHz/ {s+=$4; n++} END {if(n>0) printf \"%.2f\", s/n/1000; else print 0}' /proc/cpuinfo)", "mem_line=$(free -b | awk '/^Mem:/ {print $3, $2}')", "set -- $mem_line; mem_used=$1; mem_total=$2", "zram_used=$(cat /sys/block/zram*/mm_stat 2>/dev/null | awk '{sum+=$3} END{print sum+0}')", "zswap_pool=$(awk '/^Zswap:/ {print $2*1024}' /proc/meminfo)", "swapfile_used=$(awk '/swapfile/ {sum+=$4} END{print sum*1024+0}' /proc/swaps)", "spd_file=$(ls /sys/bus/i2c/devices/*/eeprom 2>/dev/null | head -n1)", "spd_type=$(dd if=\"$spd_file\" bs=1 skip=2 count=1 2>/dev/null | od -A n -t u1 | awk '{print int($1/16)}')", "spd_tck=$(dd if=\"$spd_file\" bs=1 skip=20 count=2 2>/dev/null | od -A n -t u1 | awk '{print $1+$2*256}')", "igpu_card=$(for c in /sys/class/drm/card[0-9]*; do [ \"$(basename $(readlink $c/device/driver 2>/dev/null))\" = \"amdgpu\" ] && echo $c && break; done)", "igpu_usage=$(cat \"$igpu_card/device/gpu_busy_percent\" 2>/dev/null || echo 0)", "igpu_hwmon=$(for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = \"amdgpu\" ] && echo $h && break; done)", "igpu_temp=$(awk '{printf \"%.1f\", $1/1000}' \"$igpu_hwmon/temp1_input\" 2>/dev/null || echo 0)", "igpu_watt=$(awk '{printf \"%.2f\", $1/1000000}' \"$igpu_hwmon/power1_average\" 2>/dev/null || echo 0)", "igpu_freq=$(cat \"$igpu_hwmon/freq1_input\" 2>/dev/null | awk '{printf \"%.0f\", $1/1000000}')", "igpu_vram_used=$(cat \"$igpu_card/device/mem_info_vram_used\" 2>/dev/null || echo 0)", "igpu_vram_total=$(cat \"$igpu_card/device/mem_info_vram_total\" 2>/dev/null || echo 0)", "igpu_name=$(cat \"$igpu_card/device/product_name\" 2>/dev/null || echo \"$cpu_name\" | sed -n 's/.*Radeon \\(.*\\) Graphics.*/AMD Radeon \\1/p')", "cpu_name=$(echo \"$cpu_name\" | sed 's/ w\\/ .*//')", "echo \"cpu_usage=$cpu_usage\"", "echo \"cpu_temp=$cpu_temp\"", "echo \"cpu_watt=$cpu_watt\"", "echo \"cpu_name=$cpu_name\"", "echo \"cpu_clock=$cpu_clock\"", "echo \"cpu_cores=$core_pcts\"", "echo \"cpu_threads=$cpu_threads\"", "echo \"mem_used=$mem_used\"", "echo \"mem_total=$mem_total\"", "echo \"zram_used=$zram_used\"", "echo \"zswap_pool=$zswap_pool\"", "echo \"swapfile_used=$swapfile_used\"", "echo \"spd_type=$spd_type\"", "echo \"spd_tck=$spd_tck\"", "echo \"igpu_usage=$igpu_usage\"", "echo \"igpu_temp=$igpu_temp\"", "echo \"igpu_watt=$igpu_watt\"", "echo \"igpu_freq=$igpu_freq\"", "echo \"igpu_name=$igpu_name\"", "echo \"igpu_vram_used=$igpu_vram_used\"", "echo \"igpu_vram_total=$igpu_vram_total\""].join("\n")
  }

  function refresh() {
    if (collectProc.running) {
      return
    }
    collectProc.command = ["bash", "-lc", collectScript()]
    collectProc.running = true
  }

  function pctFor(key) {
    if (key === "cpu") {
      return Math.max(0, Math.min(100, root.cpuUsage))
    }
    if (key === "mem") {
      return root.memTotal > 0 ? Math.max(0, Math.min(100, root.memUsed / root.memTotal * 100)) : 0
    }
    if (key === "gpu") {
      return Math.max(0, Math.min(100, root.gpuUsage))
    }
    if (key === "igpu") {
      return Math.max(0, Math.min(100, root.igpuUsage))
    }
    return 0
  }

  function stripBrand(name) {
    const brand = /^(\d+(st|nd|rd|th) Gen\s+|(AMD|Intel|NVIDIA|GeForce|Snapdragon|Qualcomm|Apple|VIA|Core|Xeon|Celeron|Pentium)(\(R\)|\(TM\)|\(C\))?\s+)/
    const kind = /\s+(CPU|GPU)$/
    let out = name.trim()
    let changed = true
    while (changed) {
      changed = false
      if (brand.test(out)) {
        out = out.replace(brand, "")
        changed = true
      }
      if (kind.test(out)) {
        out = out.replace(kind, "")
        changed = true
      }
    }
    return out.length > 0 ? out : name.trim()
  }

  function subtitleFor(key) {
    if (key === "cpu") {
      return root.cpuName.length > 0 ? stripBrand(root.cpuName) : "Processor"
    }
    if (key === "mem") {
      const gens = {
        1: "DDR5",
        2: "LPDDR5X",
        3: "LPDDR5",
        4: "LPDDR4X"
      }
      const gen = gens[root.spdType]
      if (gen && root.memSpeed > 0) {
        return gen + " " + root.memSpeed + "MHz"
      }
      return "System RAM"
    }
    if (key === "gpu") {
      return root.gpuName.length > 0 ? stripBrand(root.gpuName) : "NVIDIA GPU"
    }
    if (key === "igpu") {
      return root.igpuName.length > 0 ? stripBrand(root.igpuName) : "AMD Radeon (iGPU)"
    }
    return ""
  }

  function statsFor(key) {
    if (key === "cpu") {
      return [
        {
          label: "Clock",
          value: root.cpuClock.toFixed(2),
          unit: "GHz"
        },
        {
          label: "Temperature",
          value: Math.round(root.cpuTemp),
          unit: "°C"
        },
        root.cpuWatt > 0 ? {
          label: "Power",
          value: root.cpuWatt.toFixed(1),
          unit: "W"
        } : {
          label: "Power",
          value: "N/A"
        }]
    }
    if (key === "mem") {
      const zswap = fmtBytesParts(root.zswapPool)
      const zram = fmtBytesParts(root.zramUsed)
      const swap = fmtBytesParts(root.swapfileUsed)
      return [
        {
          label: "Zswap",
          value: zswap.num,
          unit: zswap.unit
        },
        {
          label: "ZRAM",
          value: zram.num,
          unit: zram.unit
        },
        {
          label: "Swap file",
          value: swap.num,
          unit: swap.unit
        }
      ]
    }
    if (key === "gpu") {
      return [
        {
          label: "Clock",
          value: root.gpuClock.length > 0 ? root.gpuClock : "0",
          unit: "MHz"
        },
        {
          label: "Temperature",
          value: Math.round(root.gpuTemp),
          unit: "°C"
        },
        {
          label: "Power",
          value: root.gpuWatt.toFixed(1),
          unit: "W"
        }
      ]
    }
    if (key === "igpu") {
      return [
        {
          label: "Clock",
          value: Math.round(root.igpuClock),
          unit: "MHz"
        },
        {
          label: "Temperature",
          value: Math.round(root.igpuTemp),
          unit: "°C"
        },
        {
          label: "Power",
          value: root.igpuWatt.toFixed(1),
          unit: "W"
        }
      ]
    }
    return []
  }

  function barFor(key) {
    if (key === "cpu") {
      return {
        label: "Load per thread",
        value: root.cpuThreads + " threads",
        ratio: 0,
        segments: root.cpuCores,
        mark: 0,
        mark2: 0
      }
    }
    if (key === "mem") {
      const zram = Math.max(0, Math.min(root.zramUsed, root.memUsed))
      const zswap = Math.max(0, Math.min(root.zswapPool, root.memUsed - zram))
      return {
        label: "RAM",
        value: fmtBytes(root.memUsed) + " / " + fmtBytes(root.memTotal),
        ratio: root.memTotal > 0 ? Math.max(0, Math.min(1, (root.memUsed - zram - zswap) / root.memTotal)) : 0,
        segments: [],
        mark: root.memTotal > 0 ? Math.max(0, Math.min(1, zswap / root.memTotal)) : 0,
        mark2: root.memTotal > 0 ? Math.max(0, Math.min(1, zram / root.memTotal)) : 0
      }
    }
    if (key === "gpu") {
      return {
        label: "VRAM",
        value: fmtBytes(root.gpuVramUsed) + " / " + fmtBytes(root.gpuVramTotal),
        ratio: root.gpuVramTotal > 0 ? root.gpuVramUsed / root.gpuVramTotal : 0,
        segments: [],
        mark: 0,
        mark2: 0
      }
    }
    if (key === "igpu") {
      return {
        label: "VRAM",
        value: fmtBytes(root.igpuVramUsed) + " / " + fmtBytes(root.igpuVramTotal),
        ratio: root.igpuVramTotal > 0 ? root.igpuVramUsed / root.igpuVramTotal : 0,
        segments: [],
        mark: 0,
        mark2: 0
      }
    }
    return {
      label: "",
      value: "",
      ratio: 0,
      segments: [],
      mark: 0,
      mark2: 0
    }
  }

  function pctNumFor(key) {
    const pct = root.pctFor(key)
    if (key === "gpu" || key === "igpu") {
      return Math.round(pct).toString()
    }
    return pct.toFixed(1)
  }

  function fmtBytesParts(b) {
    if (b > 999 * 1048576) {
      return {
        num: (Math.floor(b / 1073741824 * 10) / 10).toFixed(1),
        unit: "GB"
      }
    }
    if (b > 999 * 1024) {
      return {
        num: Math.round(b / 1048576),
        unit: "MB"
      }
    }
    if (b > 999) {
      return {
        num: (Math.floor(b / 1024 * 10) / 10).toFixed(1),
        unit: "KB"
      }
    }
    return {
      num: Math.round(b),
      unit: "B"
    }
  }

  function fmtBytes(b) {
    const p = fmtBytesParts(b)
    return p.num + " " + p.unit
  }

  function refreshProcs() {
    if (procProc.running) {
      return
    }
    procProc.command = ["bash", Quickshell.shellDir + "/services/procstats.sh"]
    procProc.running = true
  }

  function refreshGpu() {
    if (gpuProc.running) {
      return
    }
    gpuProc.command = ["bash", Quickshell.shellDir + "/services/nvstats.sh"]
    gpuProc.running = true
  }

  function parseGpu(text) {
    const lines = text.split("\n")
    const per = {}
    for (let i = 0; i < lines.length; i++) {
      const f = lines[i].split("\t")
      if (f[0] === "N" && f.length >= 4) {
        per[f[1]] = {
          u: parseFloat(f[2]),
          m: parseFloat(f[3])
        }
      } else if (f[0] === "D" && f.length >= 8) {
        const u = parseFloat(f[1])
        const t = parseFloat(f[2])
        const w = parseFloat(f[3])
        const vu = parseFloat(f[4])
        const vt = parseFloat(f[5])
        root.gpuUsage = isNaN(u) ? 0 : u
        root.gpuTemp = isNaN(t) ? 0 : t
        root.gpuWatt = isNaN(w) ? 0 : w
        root.gpuVramUsed = (isNaN(vu) ? 0 : vu) * 1048576
        root.gpuVramTotal = (isNaN(vt) ? 0 : vt) * 1048576
        root.gpuClock = f[6] !== undefined ? f[6].replace(/ MHz/, "") : ""
        root.gpuName = f[7] !== undefined ? f[7] : ""
      }
    }
    root.procGpu = per
    if (root.procRaw.length === 0) {
      return
    }
    let changed = false
    const merged = []
    for (let i = 0; i < root.procRaw.length; i++) {
      const r = root.procRaw[i]
      const g = per[r.pid]
      if (g !== undefined && (r.dgpu !== g.u || r.dvram !== g.m)) {
        changed = true
        merged.push(Object.assign({}, r, {
          dgpu: g.u,
          dvram: g.m
        }))
      } else {
        merged.push(r)
      }
    }
    if (changed) {
      root.procRaw = merged
    }
  }

  function procRate(cur, old, dt, p) {
    if (p === undefined || dt <= 0) {
      return 0
    }
    const d = cur - old
    return d > 0 ? d / dt : 0
  }

  function parseProcs(text) {
    const now = Date.now() / 1000
    const first = root.procTs === 0
    const dt = root.procTs > 0 ? now - root.procTs : 0
    const prev = root.procPrev
    const next = {}
    const games = {}
    const rows = []
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const f = lines[i].split("\t")
      if (f[0] === "H") {
        root.procNcpu = Math.max(1, parseInt(f[1]) || 1)
        continue
      }
      if (f[0] === "M" && f.length >= 4) {
        games[f[1]] = {
          name: f[2],
          icon: f[3]
        }
        continue
      }
      if (f.length !== 12 || f[0] !== "P") {
        continue
      }
      const pid = f[1]
      const p = prev[pid]
      const gpu = root.procGpu[pid]
      const ticks = parseFloat(f[3])
      const io = parseFloat(f[5])
      const eng = parseFloat(f[8])
      const net = parseFloat(f[10])
      rows.push({
        pid: parseInt(pid),
        name: f[2],
        cpu: root.procRate(ticks, p !== undefined ? p.t : 0, dt, p) / root.procNcpu,
        mem: parseFloat(f[4]),
        disk: io < 0 ? -1 : root.procRate(io, p !== undefined ? p.io : 0, dt, p),
        net: net < 0 ? -1 : root.procRate(net, p !== undefined ? p.n : 0, dt, p),
        dgpu: gpu !== undefined ? gpu.u : parseFloat(f[6]),
        dvram: gpu !== undefined ? gpu.m : parseFloat(f[7]),
        igpu: eng < 0 ? -1 : Math.min(100, root.procRate(eng, p !== undefined ? p.e : 0, dt, p) * 1e-7),
        ivram: parseFloat(f[9]),
        leader: parseInt(f[11])
      })
      next[pid] = {
        t: ticks,
        io: io,
        e: eng,
        n: net
      }
    }
    root.procPrev = next
    root.procTs = now
    root.procGames = games
    root.procRaw = rows
    if (first) {
      procFollowUp.restart()
    }
  }

  function procAgg(procs, key, cap) {
    let sum = 0
    let known = false
    for (let i = 0; i < procs.length; i++) {
      const v = procs[i][key]
      if (v >= 0) {
        known = true
        sum += v
      }
    }
    if (!known) {
      return -1
    }
    return cap ? Math.min(100, sum) : sum
  }

  function procCompare(a, b) {
    let r = 0
    if (root.procSort === "name") {
      const na = a.disp !== undefined ? a.disp : a.name
      const nb = b.disp !== undefined ? b.disp : b.name
      r = na.localeCompare(nb)
    } else {
      const va = a[root.procSort] < 0 ? -Infinity : a[root.procSort]
      const vb = b[root.procSort] < 0 ? -Infinity : b[root.procSort]
      r = vb - va
    }
    return root.procAsc ? -r : r
  }

  function setProcSort(key) {
    if (root.procSort === key) {
      root.procAsc = !root.procAsc
    } else {
      root.procSort = key
      root.procAsc = false
    }
  }

  function procSandboxed(comm) {
    const k = procNormal(comm)
    return k === "bwrap" || k === "firejail" || k.startsWith("flatpak") || k.startsWith("snap")
  }

  function procNormal(comm) {
    let s = String(comm)
    if (s.startsWith(".")) {
      s = s.substring(1)
    }
    return s.replace(/-wr(apped|a).*$/, "")
  }

  function procMeta(comm) {
    if (root.procMetaCache[comm] !== undefined) {
      return root.procMetaCache[comm]
    }
    const key = procNormal(comm)
    const d = AppIcons.describe(key)
    let source = d && d.icon ? Quickshell.iconPath(d.icon, "") : ""
    if (source === "" && d) {
      source = Quickshell.iconPath(key, "")
    }
    if (source === "") {
      const alias = root.procIconAliases[key.toLowerCase()]
      if (alias !== undefined) {
        source = alias
      }
    }
    let hash = 0
    for (let i = 0; i < key.length; i++) {
      hash = (hash + key.charCodeAt(i) * (i + 7)) % 997
    }
    const meta = {
      name: d && d.name ? d.name : root.procNameAliases[key.toLowerCase()] !== undefined ? root.procNameAliases[key.toLowerCase()] : key,
      icon: d && d.icon ? d.icon : "",
      source: source,
      letter: key.length > 0 ? key.charAt(0).toUpperCase() : "?",
      accent: root.procAvatarPalette[hash % root.procAvatarPalette.length]
    }
    root.procMetaCache[comm] = meta
    return meta
  }

  function procNameMatches(name, terms) {
    const hay = name.toLowerCase()
    for (let i = 0; i < terms.length; i++) {
      if (hay.indexOf(terms[i]) < 0) {
        return false
      }
    }
    return true
  }

  function procMatches(p, groupName, terms) {
    const pretty = procMeta(p.name).name.toLowerCase()
    const hay = p.name.toLowerCase() + " " + pretty + " " + p.pid + " " + groupName.toLowerCase()
    return procNameMatches(hay, terms)
  }

  function buildProcDisplay() {
    const raw = root.procRaw
    const byPid = {}
    for (let i = 0; i < raw.length; i++) {
      byPid[raw[i].pid] = raw[i]
    }
    const groups = []
    const gmap = {}
    for (let i = 0; i < raw.length; i++) {
      const r = raw[i]
      const key = byPid[r.leader] !== undefined ? r.leader : r.pid
      let g = gmap[key]
      if (g === undefined) {
        g = gmap[key] = {
          leader: key,
          name: byPid[key].name,
          procs: []
        }
        groups.push(g)
      }
      g.procs.push(r)
    }
    const terms = root.procFilter.trim().toLowerCase().split(/\s+/).filter(t => t !== "")
    for (let i = 0; i < groups.length; i++) {
      const g = groups[i]
      let dispProc = byPid[g.leader]
      if (procSandboxed(dispProc.name)) {
        let best = null
        for (let j = 0; j < g.procs.length; j++) {
          const p = g.procs[j]
          if (procSandboxed(p.name)) {
            continue
          }
          if (best === null || p.mem > best.mem || (p.mem === best.mem && p.cpu > best.cpu)) {
            best = p
          }
        }
        if (best !== null) {
          dispProc = best
        }
      }
      const meta = procMeta(dispProc.name)
      const game = root.procGames[g.leader]
      g.disp = game !== undefined && game.name.length > 0 ? game.name : meta.name
      g.icon = game !== undefined && game.icon.length > 0 ? game.icon : meta.source
      g.letter = game !== undefined && game.name.length > 0 ? game.name.charAt(0).toUpperCase() : meta.letter
      g.accent = meta.accent
      let members = g.procs
      if (terms.length > 0) {
        if (procNameMatches(g.disp, terms)) {
          members = g.procs
        } else {
          members = g.procs.filter(p => procMatches(p, g.disp, terms))
        }
        if (members.length === 0) {
          g.skip = true
          continue
        }
      }
      g.cpu = procAgg(members, "cpu", false)
      g.mem = procAgg(members, "mem", false)
      g.disk = procAgg(members, "disk", false)
      g.net = procAgg(members, "net", false)
      g.dgpu = procAgg(members, "dgpu", true)
      g.dvram = procAgg(members, "dvram", false)
      g.igpu = procAgg(members, "igpu", true)
      g.ivram = procAgg(members, "ivram", false)
      g.count = members.length
      g.members = members
    }
    groups.sort(procCompare)
    if (groups.length > root.procMax) {
      groups.length = root.procMax
    }
    const filtered = terms.length > 0
    const disp = []
    for (let i = 0; i < groups.length; i++) {
      const g = groups[i]
      if (g.skip === true) {
        continue
      }
      const expanded = filtered || root.procExpanded[g.leader] === true
      disp.push({
        kind: "group",
        key: g.leader,
        name: g.disp,
        icon: g.icon,
        letter: g.letter,
        accent: g.accent,
        count: g.count,
        expanded: expanded,
        cpu: g.cpu,
        mem: g.mem,
        disk: g.disk,
        net: g.net,
        dgpu: g.dgpu,
        dvram: g.dvram,
        igpu: g.igpu,
        ivram: g.ivram
      })
      const kids = filtered ? g.members : (expanded ? g.procs : [])
      if (kids.length > 1) {
        const sorted = kids.slice().sort(procCompare)
        for (let j = 0; j < sorted.length; j++) {
          const c = sorted[j]
          disp.push({
            kind: "proc",
            key: c.pid,
            name: c.name,
            cpu: c.cpu,
            mem: c.mem,
            disk: c.disk,
            net: c.net,
            dgpu: c.dgpu,
            dvram: c.dvram,
            igpu: c.igpu,
            ivram: c.ivram
          })
        }
      }
    }
    return disp
  }

  function toggleProcGroup(key) {
    const next = Object.assign({}, root.procExpanded)
    if (next[key] === true) {
      delete next[key]
    } else {
      next[key] = true
    }
    root.procExpanded = next
  }

  function procLeaderOf(pid) {
    for (let i = 0; i < root.procRaw.length; i++) {
      if (procRaw[i].pid === pid) {
        return procRaw[i].leader
      }
    }
    return pid
  }

  function procGroupMembers(key) {
    const pids = []
    for (let i = 0; i < root.procRaw.length; i++) {
      const r = procRaw[i]
      if (r.pid === key || r.leader === key) {
        pids.push(r.pid)
      }
    }
    return pids.length > 0 ? pids : [key]
  }

  function procSignal(pids, sig, name) {
    if (procKillProc.running) {
      return
    }
    procKillProc.target = name === undefined ? "" : name
    procKillProc.command = ["kill", "-" + sig].concat(pids.map(p => String(p)))
    procKillProc.running = true
  }

  function procCopy(text) {
    Quickshell.execDetached(["wl-copy", text])
  }

  function procCopyCmdline(pid) {
    if (procCmdProc.running) {
      return
    }
    procCmdProc.command = ["bash", "-c", "tr '\\0' ' ' < /proc/" + pid + "/cmdline 2>/dev/null"]
    procCmdProc.running = true
  }

  function procStateQuery(pid) {
    if (procStateProc.running) {
      return
    }
    procStateProc.command = ["ps", "-o", "stat=", "-p", String(pid)]
    procStateProc.running = true
  }

  function procStateStopped(out) {
    return out.trim().indexOf("T") === 0
  }

  function procMenuHeight(entries) {
    let h = procMenu.padding * 2
    for (let i = 0; i < entries.length; i++) {
      h += entries[i].separator === true ? Math.round(1 * Theme.scale) : procMenu.rowH
    }
    h += (entries.length - 1) * Math.round(1 * Theme.scale)
    if (procMenu.title !== "") {
      h += procMenu.titleH + Math.round(1 * Theme.scale) * 3
    }
    return h
  }

  function procMenuOpen(item, x, y) {
    const entries = []
    root.procMenuKind = item.kind
    root.procMenuKey = item.key
    root.procMenuName = item.name
    root.procMenuStopped = false
    procMenu.title = item.name
    if (item.kind === "group" && item.count > 1) {
      const key = item.key
      entries.push({
        label: item.expanded ? "Collapse" : "Expand",
        action: () => root.toggleProcGroup(key)
      })
      entries.push({
        label: "Copy app name",
        action: () => root.procCopy(item.name)
      })
      entries.push({
        separator: true
      })
      entries.push({
        label: "Kill all",
        danger: true,
        confirm: true,
        action: () => root.procSignal(root.procGroupMembers(key), "TERM", item.name)
      })
    } else {
      const pid = item.key
      const leader = root.procLeaderOf(pid)
      root.procStateQuery(pid)
      entries.push({
        label: "Kill",
        danger: true,
        confirm: true,
        action: () => root.procSignal([pid], "TERM", item.name)
      })
      entries.push({
        label: "Force kill",
        danger: true,
        confirm: true,
        action: () => root.procSignal([pid], "KILL", item.name)
      })
      entries.push({
        labelFn: () => root.procMenuStopped ? "Resume" : "Stop",
        action: () => root.procSignal([root.procMenuKey], root.procMenuStopped ? "CONT" : "STOP", root.procMenuName)
      })
      entries.push({
        separator: true
      })
      entries.push({
        label: "Copy PID",
        action: () => root.procCopy(String(pid))
      })
      entries.push({
        label: "Copy name",
        action: () => root.procCopy(item.name)
      })
      entries.push({
        label: "Copy command line",
        action: () => root.procCopyCmdline(pid)
      })
      if (item.kind === "proc") {
        entries.push({
          separator: true
        })
        entries.push({
          label: "Kill all in group",
          danger: true,
          confirm: true,
          action: () => root.procSignal(root.procGroupMembers(leader), "TERM", item.name)
        })
      }
    }
    const w = procMenu.width
    const h = procMenuHeight(entries)
    const inset = Math.round(4 * Theme.scale)
    const cardX = root.cardX
    const cardY = root.attached ? 0 : root.restingY
    let px = x
    let py = y
    if (py + h > cardY + root.cardHeight - inset) {
      py = y - h
    }
    if (py < cardY + inset) {
      py = cardY + inset
    }
    if (px + w > cardX + root.cardWidth - inset) {
      px = x - w
    }
    if (px < cardX + inset) {
      px = cardX + inset
    }
    procMenu.openAt(px, py, entries)
  }

  function testProcRows() {
    const rows = []
    for (let i = 0; i < procModel.count; i++) {
      const it = procModel.get(i)
      rows.push({
        kind: it.kind,
        key: it.key,
        name: it.name,
        count: it.count
      })
    }
    return rows
  }

  function testProcMenu(row) {
    if (row < 0 || row >= procModel.count) {
      return false
    }
    const item = procList.itemAtIndex(row)
    if (!item) {
      return false
    }
    const p = item.mapToItem(null, item.width / 2, item.height / 2)
    procMenuOpen(rowToModel(procModel.get(row)), p.x, p.y)
    return true
  }

  function testProcMenuState() {
    if (!procMenu.opened) {
      return {
        open: false
      }
    }
    const out = []
    for (let i = 0; i < procMenu.entries.length; i++) {
      const e = procMenu.entries[i]
      out.push({
        label: e.separator === true ? "-" : e.labelFn !== undefined ? e.labelFn() : e.label,
        danger: e.danger === true,
        confirm: e.confirm === true
      })
    }
    return {
      open: true,
      kind: root.procMenuKind,
      key: root.procMenuKey,
      name: root.procMenuName,
      x: procMenu.x,
      y: procMenu.y,
      width: procMenu.width,
      height: procMenu.height,
      entries: out
    }
  }

  function testProcMenuInvoke(index) {
    if (!procMenu.opened || index < 0 || index >= procMenu.entries.length) {
      return ""
    }
    return procMenu.invoke(index)
  }

  function testProcMenuClose() {
    if (procMenu.opened) {
      procMenu.close()
    }
    return true
  }

  function testProcRowRect(row) {
    const item = procList.itemAtIndex(row)
    if (!item) {
      return null
    }
    return item.mapToItem(null, 0, 0, item.width, item.height)
  }

  function fmtRate(b) {
    if (b >= 1073741824) {
      return (b / 1073741824).toFixed(1) + " GB/s"
    }
    if (b >= 1048576) {
      return (b / 1048576).toFixed(1) + " MB/s"
    }
    if (b >= 1024) {
      return (b / 1024).toFixed(1) + " KB/s"
    }
    return Math.round(b) + " B/s"
  }

  function procCellText(item, key) {
    const v = item[key]
    if (key === "cpu") {
      return v.toFixed(1) + "%"
    }
    if (key === "mem") {
      return fmtBytes(v)
    }
    if (key === "disk" || key === "net") {
      return v < 0 ? "—" : fmtRate(v)
    }
    if (key === "dgpu" || key === "igpu") {
      const m = item[key === "dgpu" ? "dvram" : "ivram"]
      const pct = v < 0 ? "" : Math.round(v) + "%"
      const mem = m >= 0 ? fmtBytes(m * 1024) : ""
      if (pct === "" && mem === "") {
        return "—"
      }
      if (pct === "") {
        return mem
      }
      if (mem === "") {
        return pct
      }
      return pct + " · " + mem
    }
    return v < 0 ? "—" : fmtBytes(v * 1024)
  }

  function procCellColor(item, key) {
    const v = item[key]
    if (v < 0) {
      return Theme.overlay
    }
    if (key === "cpu" && v > 50) {
      return Theme.red
    }
    if (key === "mem" && v > 1073741824) {
      return Theme.yellow
    }
    return Theme.subtext
  }

  component ProcRow: Row {
    id: prow

    property bool header: false
    property var item: null

    readonly property bool isGroup: !header && item !== null && item.kind === "group"
    readonly property bool isChild: !header && item !== null && item.kind === "proc"
    readonly property real gapS: Math.round(8 * Theme.scale)
    readonly property real chevW: Math.round(12 * Theme.scale)
    readonly property real iconW: Math.round(16 * Theme.scale)
    readonly property real padR: Math.round(12 * Theme.scale)
    readonly property real nameW: {
      let fixed = 0
      for (let i = 0; i < root.procCols.length; i++) {
        fixed += root.procCols[i].w
      }
      return prow.width - prow.chevW - prow.iconW - prow.padR - Math.round(fixed * Theme.scale) - prow.gapS * (root.procCols.length + 1)
    }

    spacing: gapS
    width: parent ? parent.width : 0
    height: header ? Math.round(18 * Theme.scale) : Math.round(22 * Theme.scale)

    Item {
      width: prow.chevW
      height: prow.height

      Icon {
        anchors.centerIn: parent
        visible: prow.isGroup && prow.item.count > 1
        name: prow.isGroup && prow.item.expanded ? "chevron-down" : "chevron-right"
        color: Theme.overlay
        font.pixelSize: Math.round(11 * Theme.scale)
      }

      MouseArea {
        anchors.fill: parent
        enabled: prow.isGroup && prow.item.count > 1
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggleProcGroup(prow.item.key)
      }
    }

    Item {
      width: prow.iconW
      height: prow.height

      Image {
        anchors.centerIn: parent
        visible: prow.isGroup && prow.item.icon !== ""
        source: prow.isGroup ? prow.item.icon : ""
        sourceSize: Qt.size(prow.iconW, prow.iconW)
      }

      Rectangle {
        anchors.centerIn: parent
        visible: prow.isGroup && prow.item.icon === ""
        width: prow.iconW
        height: prow.iconW
        radius: width / 2
        color: prow.isGroup ? prow.item.accent : "transparent"

        Text {
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: Math.round(0.5 * Theme.scale)
          anchors.verticalCenterOffset: Math.round(1 * Theme.scale)
          visible: prow.isGroup && prow.item.icon === ""
          text: prow.isGroup ? prow.item.letter : ""
          color: Theme.onAccent
          font.family: Theme.fontFamily
          font.pixelSize: Math.round(9 * Theme.scale)
          font.bold: true
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: prow.isGroup && prow.item.count > 1
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggleProcGroup(prow.item.key)
      }
    }

    Item {
      width: prow.nameW
      height: prow.height

      Text {
        id: nameTxt

        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        text: {
          if (prow.header) {
            return "Name" + (root.procSort === "name" ? (root.procAsc ? " ▴" : " ▾") : "")
          }
          if (prow.item === null) {
            return ""
          }
          if (prow.isGroup) {
            return prow.item.name + (prow.item.count > 1 ? "  (" + prow.item.count + ")" : "")
          }
          return prow.item.name
        }
        color: {
          if (prow.header) {
            return root.procSort === "name" ? Theme.text : Theme.overlay
          }
          return prow.isChild ? Theme.subtext : Theme.text
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: prow.header && root.procSort === "name"
        elide: Text.ElideRight
      }

      MouseArea {
        anchors.fill: parent
        enabled: prow.header || (prow.isGroup && prow.item.count > 1)
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
          if (prow.header) {
            root.setProcSort("name")
          } else {
            root.toggleProcGroup(prow.item.key)
          }
        }
      }
    }

    Repeater {
      model: root.procCols

      delegate: Item {
        id: cell

        required property int index
        required property var modelData

        readonly property bool active: root.procSort === cell.modelData.key

        width: Math.round(cell.modelData.w * Theme.scale)
        height: prow.height

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (prow.header) {
              return cell.modelData.label + (cell.active ? (root.procAsc ? " ▴" : " ▾") : "")
            }
            if (prow.item === null) {
              return ""
            }
            return root.procCellText(prow.item, cell.modelData.key)
          }
          color: {
            if (prow.header) {
              return cell.active ? Theme.text : Theme.overlay
            }
            if (prow.item === null) {
              return Theme.overlay
            }
            return root.procCellColor(prow.item, cell.modelData.key)
          }
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
          font.bold: prow.header && cell.active
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignRight
        }

        MouseArea {
          anchors.fill: parent
          visible: prow.header
          cursorShape: Qt.PointingHandCursor
          onClicked: root.setProcSort(cell.modelData.key)
        }
      }
    }

    Item {
      width: prow.padR
      height: 1
    }
  }

  component ProcStripeRow: Item {
    id: skelRow

    required property int index

    width: parent ? parent.width : 0
    height: Math.round(22 * Theme.scale)

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -(Theme.gap + root.contentPad)
      anchors.rightMargin: -(Theme.gap + root.contentPad)
      color: Theme.surfaceHigh
      opacity: skelRow.index % 2 === 1 ? 0.16 : 0
    }
  }

  Process {
    id: collectProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
          const m = lines[i].match(/^(\w+)=(.*)$/)
          if (!m) {
            continue
          }
          const key = m[1]
          const val = m[2].trim()
          const num = parseFloat(val)
          if (key === "cpu_usage") {
            root.cpuUsage = isNaN(num) ? 0 : num
          } else if (key === "cpu_temp") {
            root.cpuTemp = isNaN(num) ? 0 : num
          } else if (key === "cpu_watt") {
            root.cpuWatt = isNaN(num) ? 0 : num
          } else if (key === "cpu_name") {
            root.cpuName = val
          } else if (key === "cpu_clock") {
            root.cpuClock = isNaN(num) ? 0 : num
          } else if (key === "cpu_cores") {
            root.cpuCores = val.length > 0 ? val.split(" ").map(parseFloat) : []
          } else if (key === "cpu_threads") {
            root.cpuThreads = isNaN(parseInt(val)) ? 0 : parseInt(val)
          } else if (key === "mem_used") {
            root.memUsed = isNaN(num) ? 0 : num
          } else if (key === "mem_total") {
            root.memTotal = isNaN(num) ? 0 : num
          } else if (key === "zram_used") {
            root.zramUsed = isNaN(num) ? 0 : num
          } else if (key === "zswap_pool") {
            root.zswapPool = isNaN(num) ? 0 : num
          } else if (key === "swapfile_used") {
            root.swapfileUsed = isNaN(num) ? 0 : num
          } else if (key === "spd_type") {
            root.spdType = isNaN(num) ? 0 : num
          } else if (key === "spd_tck") {
            root.spdTck = isNaN(num) ? 0 : num
          } else if (key === "igpu_usage") {
            root.igpuUsage = isNaN(num) ? 0 : num
          } else if (key === "igpu_temp") {
            root.igpuTemp = isNaN(num) ? 0 : num
          } else if (key === "igpu_watt") {
            root.igpuWatt = isNaN(num) ? 0 : num
          } else if (key === "igpu_freq") {
            root.igpuClock = isNaN(num) ? 0 : num
          } else if (key === "igpu_name") {
            root.igpuName = val
          } else if (key === "igpu_vram_used") {
            root.igpuVramUsed = isNaN(num) ? 0 : num
          } else if (key === "igpu_vram_total") {
            root.igpuVramTotal = isNaN(num) ? 0 : num
          }
        }
        root.primed = true
      }
    }
  }

  Process {
    id: procProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: root.parseProcs(text)
    }
  }

  Process {
    id: gpuProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: root.parseGpu(text)
    }
  }

  MouseArea {
    id: procMenuHover

    parent: root.contentItem
    z: 100
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    enabled: procMenu.opened
    hoverEnabled: procMenu.opened
    onPositionChanged: mouse => procMenu.trackHover(mouse.x, mouse.y)
  }

  ContextMenu {
    id: procMenu

    parent: root.contentItem
    z: 101
  }

  Process {
    id: procStateProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: root.procMenuStopped = root.procStateStopped(text)
    }
  }

  Process {
    id: procKillProc

    property string target: ""

    running: false
    onExited: code => {
      if (code !== 0) {
        Quickshell.execDetached(["dunstify", "-a", "quickshell", "-u", "normal", "Quickshell", procKillProc.target.length > 0 ? "Failed to signal " + procKillProc.target : "Failed to signal process"])
      }
    }
  }

  Process {
    id: procCmdProc

    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text.trim()
        if (t.length > 0) {
          root.procCopy(t)
        }
      }
    }
  }

  Connections {
    target: root

    function onOpenChanged() {
      if (!root.open && procMenu.opened) {
        procMenu.close()
      }
    }
  }

  ListModel {
    id: procModel

    dynamicRoles: true
  }

  Timer {
    id: procTimer

    interval: 1000
    running: root.open
    repeat: true
    onTriggered: root.refreshProcs()
  }

  Timer {
    id: procFollowUp

    interval: 250
    running: false
    repeat: false
    onTriggered: if (root.open) {
      root.refreshProcs()
    }
  }

  Timer {
    id: gpuTimer

    interval: 1000
    running: root.open
    repeat: true
    onTriggered: root.refreshGpu()
  }

  Timer {
    id: refreshTimer

    interval: root.animMs
    running: root.open
    repeat: true
    onTriggered: root.refresh()
  }

  onOpened: {
    root.primed = false
    root.refresh()
    root.procPrev = ({})
    root.procTs = 0
    root.procRaw = []
    root.procGpu = ({})
    root.procExpanded = ({})
    root.procGames = ({})
    root.procNcpu = 1
    filterInput.text = ""
    root.procFilter = ""
    root.refreshProcs()
    root.refreshGpu()
  }

  onContentClicked: pos => {
    const b = procFilterBox.mapToItem(null, 0, 0)
    if (pos.x < b.x || pos.y < b.y || pos.x > b.x + procFilterBox.width || pos.y > b.y + procFilterBox.height) {
      filterInput.focus = false
    }
  }

  PanelHeader {
    id: powerHeader

    title: "Power"
  }

  Grid {
    id: statGrid

    columns: 2
    spacing: Theme.gap

    Repeater {
      model: [
        {
          key: "cpu",
          title: "CPU",
          icon: "cpu",
          accent: Theme.primary
        },
        {
          key: "mem",
          title: "Memory",
          icon: "stack-2",
          accent: Theme.yellow
        },
        {
          key: "gpu",
          title: "dGPU",
          icon: "device-desktop-analytics",
          accent: Theme.mauve
        },
        {
          key: "igpu",
          title: "iGPU",
          icon: "device-analytics",
          accent: Theme.teal
        }
      ]

      delegate: Rectangle {
        id: card

        required property var modelData

        readonly property var stats: root.statsFor(modelData.key)
        readonly property var bar: root.barFor(modelData.key)
        readonly property bool hasBar: bar.label !== ""
        readonly property real bodyPad: Math.round(6 * Theme.scale)

        width: (root.contentWidth - Theme.gap) / 2
        radius: Theme.cardRadius
        color: Theme.surface
        antialiasing: true
        implicitHeight: cardCol.implicitHeight + Theme.gap * 2 + (hasBar ? Math.round(4 * Theme.scale) : 0)

        Column {
          id: cardCol

          anchors.fill: parent
          anchors.margins: Theme.gap
          spacing: Theme.gap

          Row {
            width: parent.width
            spacing: Math.round(10 * Theme.scale)

            Rectangle {
              width: Math.round(38 * Theme.scale)
              height: width
              radius: Theme.rowRadius
              color: Qt.rgba(card.modelData.accent.r, card.modelData.accent.g, card.modelData.accent.b, 0.16)
              antialiasing: true

              Icon {
                anchors.centerIn: parent
                name: card.modelData.icon
                color: card.modelData.accent
                font.pixelSize: Theme.iconSizeLarge
              }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Math.round(38 * Theme.scale) - pctText.width - parent.spacing * 2

              Text {
                width: parent.width
                text: card.modelData.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.subtitleFor(card.modelData.key)
                color: Theme.overlay
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
              }
            }

            Row {
              id: pctText

              anchors.verticalCenter: parent.verticalCenter
              spacing: Math.round(3 * Theme.scale)

              Text {
                id: pctNum

                text: root.pctNumFor(card.modelData.key)
                color: card.modelData.accent
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(24 * Theme.scale)
                font.bold: true
              }

              Text {
                anchors.baseline: pctNum.baseline
                text: "%"
                color: card.modelData.accent
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(13 * Theme.scale)
                font.bold: true
              }
            }
          }

          Column {
            x: card.bodyPad
            width: parent.width - card.bodyPad * 2
            spacing: Math.round(4 * Theme.scale)
            visible: card.bar.label !== ""

            Item {
              width: parent.width
              height: visible ? labelTxt.implicitHeight : 0
              visible: card.bar.label !== ""

              Text {
                id: labelTxt

                anchors.left: parent.left
                text: card.bar.label
                color: Theme.overlay
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: labelTxt.verticalCenter
                visible: card.bar.value !== ""
                text: card.bar.value
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }
            }

            Row {
              width: parent.width
              spacing: Math.round(3 * Theme.scale)
              visible: card.bar.segments.length > 0

              Repeater {
                model: card.bar.segments.length

                delegate: Rectangle {
                  id: seg

                  required property int index

                  width: (parent.width - parent.spacing * (card.bar.segments.length - 1)) / card.bar.segments.length
                  height: Math.round(6 * Theme.scale)
                  radius: height / 2
                  color: Theme.surfaceHigh

                  Item {
                    id: segFill

                    readonly property real load: Math.max(0, Math.min(100, root.cpuCores[seg.index] ?? 0))
                    readonly property real rawWidth: load / 100 * seg.width

                    width: Math.max(seg.height, rawWidth)
                    height: parent.height
                    clip: true
                    opacity: load > 0 ? Math.min(1, rawWidth / seg.height) : 0

                    Behavior on width {
                      enabled: root.primed

                      NumberAnimation {
                        duration: root.animMs
                      }
                    }

                    Behavior on opacity {
                      enabled: root.primed

                      NumberAnimation {
                        duration: root.animMs
                      }
                    }

                    Rectangle {
                      width: parent.height
                      height: parent.height
                      radius: height / 2
                      color: card.modelData.accent
                    }

                    Rectangle {
                      x: parent.height / 2
                      width: Math.max(0, parent.width - parent.height)
                      height: parent.height
                      color: card.modelData.accent
                    }

                    Rectangle {
                      x: parent.width - parent.height
                      width: parent.height
                      height: parent.height
                      radius: height / 2
                      color: card.modelData.accent
                    }
                  }
                }
              }
            }

            Rectangle {
              id: barTrack

              readonly property real seg1: Math.max(0, Math.min(1, card.bar.ratio)) * width
              readonly property real seg2: seg1 + Math.max(0, Math.min(1, card.bar.mark)) * width
              readonly property real segEnd: seg2 + Math.max(0, Math.min(1, card.bar.mark2)) * width
              readonly property color zswapColor: Qt.rgba(card.modelData.accent.r * 0.75 + color.r * 0.15, card.modelData.accent.g * 0.75 + color.g * 0.15, card.modelData.accent.b * 0.75 + color.b * 0.15, 1)
              readonly property color zramColor: Qt.rgba(card.modelData.accent.r * 0.5 + color.r * 0.3, card.modelData.accent.g * 0.5 + color.g * 0.3, card.modelData.accent.b * 0.5 + color.b * 0.3, 1)

              width: parent.width
              height: Math.round(6 * Theme.scale)
              radius: height / 2
              visible: card.bar.segments.length === 0
              color: Theme.surfaceHigh
              clip: true

              Rectangle {
                visible: card.bar.ratio > 0
                width: Math.min(barTrack.seg1 + parent.height / 2, barTrack.segEnd)
                height: parent.height
                radius: parent.radius
                color: card.modelData.accent

                Behavior on width {
                  enabled: root.primed

                  NumberAnimation {
                    duration: root.animMs
                  }
                }
              }

              Rectangle {
                visible: card.bar.mark > 0
                x: barTrack.seg1
                width: Math.max(0, Math.min(barTrack.seg2 + parent.height / 2, barTrack.segEnd) - barTrack.seg1)
                height: parent.height
                color: barTrack.zswapColor

                Behavior on x {
                  enabled: root.primed

                  NumberAnimation {
                    duration: root.animMs
                  }
                }

                Behavior on width {
                  enabled: root.primed

                  NumberAnimation {
                    duration: root.animMs
                  }
                }
              }

              Rectangle {
                visible: card.bar.mark2 > 0
                x: barTrack.seg2
                width: Math.max(0, barTrack.segEnd - parent.height / 2 - barTrack.seg2)
                height: parent.height
                color: barTrack.zramColor

                Behavior on x {
                  enabled: root.primed

                  NumberAnimation {
                    duration: root.animMs
                  }
                }

                Behavior on width {
                  enabled: root.primed

                  NumberAnimation {
                    duration: root.animMs
                  }
                }
              }

              Rectangle {
                visible: barTrack.segEnd > 0
                x: barTrack.segEnd - parent.height
                width: parent.height
                height: parent.height
                radius: height / 2
                color: card.bar.mark2 > 0 ? barTrack.zramColor : card.bar.mark > 0 ? barTrack.zswapColor : card.modelData.accent

                Behavior on x {
                  enabled: root.primed

                  NumberAnimation {
                    duration: root.animMs
                  }
                }
              }
            }
          }

          Rectangle {
            x: card.bodyPad
            width: parent.width - card.bodyPad * 2
            height: 1
            color: Theme.surfaceHigher
            opacity: 0.4
            visible: card.bar.label !== ""
          }

          Row {
            x: card.bodyPad
            width: parent.width - card.bodyPad * 2
            spacing: Theme.gap
            visible: card.stats.length > 0

            Repeater {
              id: statRep

              model: card.stats

              delegate: Column {
                required property var modelData

                width: (parent.width - Theme.gap * (statRep.count - 1)) / statRep.count
                spacing: Math.round(3 * Theme.scale)

                Text {
                  width: parent.width
                  text: modelData.label
                  color: Theme.overlay
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeSmall
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Math.round(4 * Theme.scale)

                  Text {
                    id: statVal

                    text: modelData.value
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                  }

                  Text {
                    visible: modelData.unit !== undefined
                    anchors.verticalCenter: statVal.verticalCenter
                    text: modelData.unit ?? ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(9 * Theme.scale)
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  SectionHeader {
    id: procSectionHeader

    Rectangle {
      id: procFilterBox

      width: Math.round(150 * Theme.scale)
      height: Math.round(20 * Theme.scale)
      radius: height / 2
      color: Theme.surfaceHigh
      border.width: filterInput.activeFocus ? Math.round(1 * Theme.scale) : 0
      border.color: Theme.primary

      Icon {
        id: filterIcon

        anchors.left: parent.left
        anchors.leftMargin: Math.round(7 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        color: filterInput.activeFocus ? Theme.primary : Theme.overlay
        font.pixelSize: Math.round(11 * Theme.scale)
      }

      TextInput {
        id: filterInput

        anchors.left: filterIcon.right
        anchors.leftMargin: Math.round(5 * Theme.scale)
        anchors.right: parent.right
        anchors.rightMargin: Math.round(7 * Theme.scale)
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        onTextChanged: root.procFilter = text
        Keys.onEscapePressed: {
          text = ""
          focus = false
        }

        Text {
          anchors.fill: parent
          visible: filterInput.text === ""
          text: "Filter…"
          color: Theme.overlay
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
          verticalAlignment: TextInput.AlignVCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: filterInput.forceActiveFocus()
      }
    }
  }

  Rectangle {
    id: procCard

    width: root.contentWidth
    radius: Theme.cardRadius
    color: Theme.surface
    antialiasing: true
    implicitHeight: procCol.implicitHeight + Theme.gap * 2

    Column {
      id: procCol

      anchors.fill: parent
      anchors.margins: Theme.gap
      spacing: Math.round(3 * Theme.scale)

      ProcRow {
        header: true
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Theme.surfaceHigher
        opacity: 0.5
      }

      Column {
        id: procStripes

        readonly property real rowH: Math.round(22 * Theme.scale)
        readonly property real rowGap: Math.round(3 * Theme.scale)
        readonly property real avail: root.maxCardHeight - (root.contentPad * 2 + Theme.gap * 5 + rowGap * 2 + Math.round(18 * Theme.scale) + 1 + powerHeader.height + statGrid.height + procSectionHeader.height)
        readonly property int uncappedRows: Math.max(0, Math.floor((avail + rowGap) / (rowH + rowGap)))
        readonly property int rowCount: Math.max(1, Math.min(root.procMax, uncappedRows))
        readonly property real rowFill: rowCount * rowH + (rowCount - 1) * rowGap

        width: parent.width
        height: uncappedRows <= root.procMax ? Math.max(avail, rowFill) : rowFill
        spacing: rowGap
        visible: root.procRaw.length === 0

        Repeater {
          model: procStripes.rowCount

          delegate: ProcStripeRow {}
        }
      }

      ListView {
        id: procList

        width: parent.width
        height: contentHeight
        interactive: false
        spacing: Math.round(3 * Theme.scale)
        visible: root.procRaw.length !== 0
        model: procModel

        delegate: Item {
          id: rowWrap

          required property int index
          required property string kind
          required property int key
          required property string name
          required property string icon
          required property string letter
          required property color accent
          required property int count
          required property bool expanded
          required property real cpu
          required property real mem
          required property real disk
          required property real net
          required property real dgpu
          required property real dvram
          required property real igpu
          required property real ivram

          readonly property var rowData: ({
              kind: kind,
              key: key,
              name: name,
              icon: icon,
              letter: letter,
              accent: accent,
              count: count,
              expanded: expanded,
              cpu: cpu,
              mem: mem,
              disk: disk,
              net: net,
              dgpu: dgpu,
              dvram: dvram,
              igpu: igpu,
              ivram: ivram
            })

          width: procList.width
          height: Math.round(22 * Theme.scale)

          Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -(Theme.gap + root.contentPad)
            anchors.rightMargin: -(Theme.gap + root.contentPad)
            color: Theme.surfaceHigh
            opacity: rowHover.hovered ? 0.55 : rowWrap.index % 2 === 1 ? 0.16 : 0
            Behavior on opacity {
              NumberAnimation {
                duration: 120
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.ArrowCursor
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) {
                const p = rowWrap.mapToItem(null, mouse.x, mouse.y)
                root.procMenuOpen(rowWrap.rowData, p.x, p.y)
              }
            }
          }

          ProcRow {
            width: parent.width
            height: parent.height
            item: rowWrap.rowData
          }

          HoverHandler {
            id: rowHover
          }
        }

        add: Transition {
          NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
          }
        }

        addDisplaced: Transition {
          NumberAnimation {
            property: "y"
            duration: 150
            easing.type: Easing.OutCubic
          }
        }

        remove: Transition {
          NumberAnimation {
            property: "opacity"
            to: 0
            duration: 150
            easing.type: Easing.OutCubic
          }
        }

        removeDisplaced: Transition {
          NumberAnimation {
            property: "y"
            duration: 150
            easing.type: Easing.OutCubic
          }
        }

        move: Transition {
          NumberAnimation {
            property: "y"
            duration: 150
            easing.type: Easing.OutCubic
          }
        }

        moveDisplaced: Transition {
          NumberAnimation {
            property: "y"
            duration: 150
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
