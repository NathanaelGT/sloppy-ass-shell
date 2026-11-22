// Wi-Fi QR scan tool. One Bun process owns one ffmpeg child; nothing touches
// the disk: the camera stream arrives as motion-JPEG on ffmpeg's stdout and
// leaves as one JSON line per frame on stdout (frame as base64, plus the
// decoded Wi-Fi payload when a code is found).
//
// Modes:
//   qrscan.mjs               live camera scan (ffmpeg retries: 3x, 1s backoff)
//   qrscan.mjs --file <p>    decode an image file, print {"payload": "..."}
//   qrscan.mjs --paste       decode the clipboard's image offer, same output
//
// Exit codes: 0 stopped, 2 camera unavailable, 3 missing decoder deps,
// 4 no image on the clipboard.

import { spawn, spawnSync } from "node:child_process"

const FFMPEG_COMMON = ["-hide_banner", "-loglevel", "error", "-nostdin", "-f", "mjpeg", "-q:v", "5", "pipe:1"]

// Live preview fps sits at 30; the QR decode runs decoupled (every 4th
// frame, ~7.5 Hz) so the jsQR cost stays a fraction of one core.
const DECODE_EVERY = 4

let jsQR
let jpegJs
try {
  jsQR = (await import("jsqr")).default
  jpegJs = await import("jpeg-js")
} catch {
  console.log(JSON.stringify({ error: "missing-deps" }))
  process.exit(3)
}

function emit(message) {
  console.log(JSON.stringify(message))
}

function decodeFrame(bytes) {
  const image = jpegJs.decode(bytes, { useTArray: true, formatAsRGBA: true })
  const code = jsQR(image.data, image.width, image.height)
  return { image, payload: code ? code.data : "" }
}

// Splits an interleaved motion-JPEG stream into complete SOI..EOI frames.
function frameReader(onFrame) {
  const soi = Buffer.from([0xff, 0xd8])
  const eoi = Buffer.from([0xff, 0xd9])
  let buf = Buffer.alloc(0)
  return chunk => {
    buf = buf.length === 0 ? chunk : Buffer.concat([buf, chunk])
    for (;;) {
      const start = buf.indexOf(soi)
      if (start < 0) {
        buf = buf.subarray(Math.max(0, buf.length - 1))
        return
      }
      const end = buf.indexOf(eoi, start + 2)
      if (end < 0) {
        buf = buf.subarray(start)
        return
      }
      const frame = buf.subarray(start, end + 2)
      buf = buf.subarray(end + 2)
      onFrame(frame)
    }
  }
}

function decodeOneShot(source, onSourceEnd) {
  const reader = frameReader(frame => {
    const { payload } = decodeFrame(frame)
    emit({ payload })
    cleanup()
    process.exit(0)
  })
  let done = false
  const cleanup = () => {
    if (done) {
      return
    }
    done = true
    onSourceEnd()
  }
  source.stdout.on("data", reader)
  source.on("exit", () => {
    cleanup()
    emit({ payload: "" })
    process.exit(0)
  })
}

function pasteImageType() {
  const list = spawnSync("wl-paste", ["--list-types"])
  if (list.status !== 0) {
    return ""
  }
  const types = list.stdout.toString().split("\n")
  return types.find(t => t.startsWith("image/")) ?? ""
}

function live() {
  const device = process.env.QRCAM_DEVICE ?? "/dev/video0"
  let srcArgs = ["-f", "v4l2", "-i", device]
  if (process.env.QRCAM_FILE) {
    srcArgs = ["-re", "-loop", "1", "-framerate", "30", "-i", process.env.QRCAM_FILE]
  } else if (process.env.QRCAM_LAVFI) {
    srcArgs = ["-re", "-f", "lavfi", "-i", "testsrc2=size=480x360:rate=30"]
  }
  let attempts = 0
  let stopping = false
  let retryTimer = null
  let ff = null
  let seen = 0
  const reader = frameReader(frame => {
    const line = { frame: frame.toString("base64") }
    seen += 1
    if (seen % DECODE_EVERY === 0) {
      const { payload } = decodeFrame(frame)
      if (payload !== "") {
        line.payload = payload
      }
    }
    emit(line)
  })
  const startFf = () => {
    if (stopping) {
      return
    }
    ff = spawn("ffmpeg", ["-hide_banner", "-loglevel", "error", "-nostdin", ...srcArgs, "-vf", "fps=30,scale=480:-2", ...FFMPEG_COMMON], { stdio: ["ignore", "pipe", "inherit"] })
    ff.stdout.on("data", reader)
    ff.on("exit", () => {
      if (stopping) {
        return
      }
      attempts += 1
      if (attempts > 3) {
        emit({ error: "camera-unavailable" })
        process.exit(2)
      }
      retryTimer = setTimeout(startFf, 1000)
    })
  }
  const stop = () => {
    stopping = true
    if (retryTimer) {
      clearTimeout(retryTimer)
    }
    if (ff) {
      ff.kill()
    }
    process.exit(0)
  }
  process.on("SIGTERM", stop)
  process.on("SIGINT", stop)
  startFf()
}

const mode = process.argv[2]
if (mode === "--file") {
  const path = process.argv[3]
  if (!path) {
    emit({ error: "missing-path" })
    process.exit(1)
  }
  const ff = spawn("ffmpeg", ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", path, "-vf", "scale=480:-2", ...FFMPEG_COMMON], { stdio: ["ignore", "pipe", "inherit"] })
  decodeOneShot(ff, () => ff.kill())
} else if (mode === "--paste") {
  const type = pasteImageType()
  if (type === "") {
    emit({ error: "no-image" })
    process.exit(4)
  }
  const wl = spawn("wl-paste", ["--type", type], { stdio: ["ignore", "pipe", "ignore"] })
  const ff = spawn("ffmpeg", ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", "pipe:0", "-vf", "scale=480:-2", ...FFMPEG_COMMON], { stdio: ["pipe", "pipe", "inherit"] })
  wl.stdout.pipe(ff.stdin)
  decodeOneShot(ff, () => {
    wl.kill()
    ff.kill()
  })
} else {
  live()
}
