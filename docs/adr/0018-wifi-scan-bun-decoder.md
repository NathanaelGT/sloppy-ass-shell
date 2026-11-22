# The Wi-Fi scan card runs its decoder in a Bun subprocess

## Status

accepted

## Context

Nothing in Quickshell or Qt Quick decodes QR codes, and Quickshell 0.3.2
ships no camera API — its one capture type, `ScreencopyView`, only mirrors
monitors and toplevels. The Wi-Fi scan card therefore needs a camera source
and a decoder from outside the QML tree.

The alternatives, and why each lost:

- **zbar (`zbarimg`) as an installed dependency**: one more system package
  the user must have; also a per-frame process spawn, since zbarimg reads
  files. The shell already carries Bun for other tooling.
- **Quickshell rebuilt with QtMultimedia** (`quickshell.withModules
  [qt6.qtmultimedia]`): puts the whole multimedia stack in the shell's
  closure to render a 480 px viewfinder and still needs a separate QR
  decoder; a camera driver that hangs would then hang inside the shell
  process (the same isolation argument omarchy-webcam answers by running
  its preview as a second Quickshell instance).
- **A pure-QML decoder**: none exists; porting one to QML/JS would be slower
  than the measured budget and a maintenance sink.
- **A disk frame swap** (ffmpeg writes `frame.jpg`, the panel re-points
  `Image.source` at it with a cache-buster): proven in the wild but it
  violates the no-disk rule for a privacy-sensitive flow, adds a
  filesystem-write/renaming race between producer and consumer, and makes
  the pixmap cache the sync point instead of the process pipe.
- **In-shell pixel readback** (decoding frames inside the shell process):
  couples the shell's frame loop to a wedged camera — the failure this
  architecture exists to avoid — and would still need a JS decoder for the
  QR payload.

The chosen decoder is **jsQR** (Apache-2.0, npm `jsqr`) driven by **Bun**,
with **jpeg-js** (BSD-3-Clause, npm `jpeg-js`) turning the motion-JPEG
frames into pixels. They live in `tools/qrscan/` (outside the QML tree, so
qmlformat/qmllint never see them) with `node_modules` git-ignored.

The camera is read by one `ffmpeg` child (`-f v4l2`, motion-JPEG on stdout)
owned by one Bun process; the panel starts and stops that single process.
Frames are measured, per a prototype at the chosen size: 8.7 KB JPEG →
11.6 KB base64, ~25 ms to decode, at 480 px wide. The preview runs at
30 fps; decoding for the QR payload is decoupled from it — every 4th frame
(~7.5 Hz), since a held code does not move — which keeps the jsQR cost
(~25 ms per decoded frame) around a fifth of one core instead of the ~75%
decoding every frame would take.

## Decision

- The preview never touches the disk. Frames travel as JSON lines over the
  process's stdout (frame as base64, plus the decoded payload when a code is
  found), and the panel shows each frame through a `data:` URI on an
  `Image` with `cache: false` — no written frame file, no cache-buster
  rename race.
- Capture lives in the subprocess so a wedged camera driver or decoder
  cannot take the shell down; killing Bun reports an inline error in the
  card and re-opening starts a fresh scan.
- Preview smoothness and scan latency are tuned separately: the 30 fps
  frame stream is only base64 + display, while the payload decode runs at
  a fraction of that rate.
- Failure states are explicit: an ffmpeg that keeps dying is retried three
  times with a one-second backoff and then reports "Camera unavailable";
  a missing Bun or an unloadable decoder reports "Decoder missing" (Bun's
  auto-install can mask missing `node_modules` on a networked machine).
- Paste shares the exact decoder: clipboard bytes are piped through ffmpeg
  into the tool's one-shot mode, so there is one decoder and one
  parse-and-join path for camera, file and clipboard.

## Consequences

`tools/qrscan/` needs `bun install` before the scan card works on a fresh
machine; without it the card reports "Decoder missing" and paste stays
usable as the fallback. The card's preview content is whatever the camera
serves — with a privacy shutter closed that is the camera's own placeholder
image, which looks like a broken preview but is the live feed.
