// Regenerates the Wi-Fi scan fixtures (.scratch/wifi-qr-scan/fixtures/*.png)
// used by the driver's wifiScanDecode seam:  bun run fixtures

import QRCode from "qrcode"
import { mkdirSync } from "node:fs"

const dir = new URL("../../.scratch/wifi-qr-scan/fixtures/", import.meta.url).pathname
mkdirSync(dir, { recursive: true })

const fixtures = {
  "wpa.png": "WIFI:T:WPA;S:FixWpa;P:password123;;",
  "open.png": "WIFI:T:nopass;S:FixOpen;;",
  "escaped.png": "WIFI:T:WPA;S:esc\\;aped\\:net;P:key\\,\\\\value;;",
  "hidden.png": "WIFI:T:WPA;S:FixHidden;P:hiddenpass;H:true;;",
  "url.png": "https://example.com/wifi"
}

for (const [name, payload] of Object.entries(fixtures)) {
  await QRCode.toFile(dir + name, payload, { width: 480, margin: 2, errorCorrectionLevel: "M" })
  console.log(name, "=>", payload)
}
