// QR Code generator library (TypeScript), byte mode port
//
// Copyright (c) Project Nayuki. (MIT License)
// https://www.nayuki.io/page/qr-code-generator-library
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
// - The above copyright notice and this permission notice shall be included in
//   all copies or substantial portions of the Software.
// - The Software is provided "as is", without warranty of any kind, express or
//   implied, including but not limited to the warranties of merchantability,
//   fitness for a particular purpose and noninfringement. In no event shall the
//   authors or copyright holders be liable for any claim, damages or other
//   liability, whether in an action of contract, tort or otherwise, arising from,
//   out of or in connection with the Software or the use or other dealings in the
//   Software.

.pragma library

var ECC_FORMAT_BITS = [1, 0, 3, 2]

var ECC_CODEWORDS_PER_BLOCK = [
  [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
  [-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
  [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
]

var NUM_ERROR_CORRECTION_BLOCKS = [
  [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
  [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
  [-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
  [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81]
]

function encode(text, ecc, options) {
  const opts = options ? options : {}
  const minVersion = opts.minVersion ? opts.minVersion : 1
  const maxVersion = opts.maxVersion ? opts.maxVersion : 40
  const mask = opts.mask === undefined ? -1 : opts.mask
  const bytes = toUtf8(text)
  let version
  for (version = minVersion; ; version++) {
    const capacity = getNumDataCodewords(version, ecc) * 8
    const charCountBits = version <= 9 ? 8 : 16
    if (4 + charCountBits + bytes.length * 8 <= capacity) break
    if (version >= maxVersion) throw new Error("Data too long")
  }
  const charCountBits = version <= 9 ? 8 : 16
  const bits = []
  appendBits(4, 4, bits)
  appendBits(bytes.length, charCountBits, bits)
  for (let i = 0; i < bytes.length; i++) appendBits(bytes[i], 8, bits)
  const capacityBits = getNumDataCodewords(version, ecc) * 8
  appendBits(0, Math.min(4, capacityBits - bits.length), bits)
  appendBits(0, (8 - bits.length % 8) % 8, bits)
  for (let pad = 0xec; bits.length < capacityBits; pad ^= 0xec ^ 0x11) appendBits(pad, 8, bits)
  const dataCodewords = []
  while (dataCodewords.length * 8 < bits.length) dataCodewords.push(0)
  for (let i = 0; i < bits.length; i++) dataCodewords[i >>> 3] |= bits[i] << (7 - (i & 7))
  return build(version, ecc, dataCodewords, mask)
}

function build(version, ecc, dataCodewords, msk) {
  const size = version * 4 + 17
  const modules = []
  const isFunction = []
  for (let y = 0; y < size; y++) {
    const row = []
    const funcRow = []
    for (let x = 0; x < size; x++) {
      row.push(false)
      funcRow.push(false)
    }
    modules.push(row)
    isFunction.push(funcRow)
  }
  const ctx = { version: version, ecc: ecc, size: size, modules: modules, isFunction: isFunction }
  drawFunctionPatterns(ctx)
  drawCodewords(ctx, addEccAndInterleave(ctx, dataCodewords))
  if (msk === -1) {
    let minPenalty = 1000000000
    for (let i = 0; i < 8; i++) {
      applyMask(ctx, i)
      drawFormatBits(ctx, i)
      const penalty = getPenaltyScore(ctx)
      if (penalty < minPenalty) {
        msk = i
        minPenalty = penalty
      }
      applyMask(ctx, i)
    }
  }
  applyMask(ctx, msk)
  drawFormatBits(ctx, msk)
  return { size: size, modules: modules }
}

function drawFunctionPatterns(ctx) {
  for (let i = 0; i < ctx.size; i++) {
    setFunctionModule(ctx, 6, i, i % 2 === 0)
    setFunctionModule(ctx, i, 6, i % 2 === 0)
  }
  drawFinderPattern(ctx, 3, 3)
  drawFinderPattern(ctx, ctx.size - 4, 3)
  drawFinderPattern(ctx, 3, ctx.size - 4)
  const positions = getAlignmentPatternPositions(ctx.version, ctx.size)
  const count = positions.length
  for (let i = 0; i < count; i++) {
    for (let j = 0; j < count; j++) {
      const corner = (i === 0 && j === 0) || (i === 0 && j === count - 1) || (i === count - 1 && j === 0)
      if (!corner) drawAlignmentPattern(ctx, positions[i], positions[j])
    }
  }
  drawFormatBits(ctx, 0)
  drawVersion(ctx)
}

function drawFormatBits(ctx, mask) {
  const data = ECC_FORMAT_BITS[ctx.ecc] << 3 | mask
  let rem = data
  for (let i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >>> 9) * 0x537)
  const bits = (data << 10 | rem) ^ 0x5412
  for (let i = 0; i <= 5; i++) setFunctionModule(ctx, 8, i, getBit(bits, i))
  setFunctionModule(ctx, 8, 7, getBit(bits, 6))
  setFunctionModule(ctx, 8, 8, getBit(bits, 7))
  setFunctionModule(ctx, 7, 8, getBit(bits, 8))
  for (let i = 9; i < 15; i++) setFunctionModule(ctx, 14 - i, 8, getBit(bits, i))
  for (let i = 0; i < 8; i++) setFunctionModule(ctx, ctx.size - 1 - i, 8, getBit(bits, i))
  for (let i = 8; i < 15; i++) setFunctionModule(ctx, 8, ctx.size - 15 + i, getBit(bits, i))
  setFunctionModule(ctx, 8, ctx.size - 8, true)
}

function drawVersion(ctx) {
  if (ctx.version < 7) return
  let rem = ctx.version
  for (let i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >>> 11) * 0x1f25)
  const bits = ctx.version << 12 | rem
  for (let i = 0; i < 18; i++) {
    const color = getBit(bits, i)
    const a = ctx.size - 11 + i % 3
    const b = Math.floor(i / 3)
    setFunctionModule(ctx, a, b, color)
    setFunctionModule(ctx, b, a, color)
  }
}

function drawFinderPattern(ctx, x, y) {
  for (let dy = -4; dy <= 4; dy++) {
    for (let dx = -4; dx <= 4; dx++) {
      const dist = Math.max(Math.abs(dx), Math.abs(dy))
      const xx = x + dx
      const yy = y + dy
      if (xx >= 0 && xx < ctx.size && yy >= 0 && yy < ctx.size) setFunctionModule(ctx, xx, yy, dist !== 2 && dist !== 4)
    }
  }
}

function drawAlignmentPattern(ctx, x, y) {
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) setFunctionModule(ctx, x + dx, y + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1)
  }
}

function setFunctionModule(ctx, x, y, isDark) {
  ctx.modules[y][x] = isDark
  ctx.isFunction[y][x] = true
}

function addEccAndInterleave(ctx, data) {
  const version = ctx.version
  const ecc = ctx.ecc
  const numBlocks = NUM_ERROR_CORRECTION_BLOCKS[ecc][version]
  const blockEccLen = ECC_CODEWORDS_PER_BLOCK[ecc][version]
  const rawCodewords = Math.floor(getNumRawDataModules(version) / 8)
  const numShortBlocks = numBlocks - rawCodewords % numBlocks
  const shortBlockLen = Math.floor(rawCodewords / numBlocks)
  const blocks = []
  const rsDiv = reedSolomonComputeDivisor(blockEccLen)
  for (let i = 0, k = 0; i < numBlocks; i++) {
    const dat = data.slice(k, k + shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1))
    k += dat.length
    const eccBytes = reedSolomonComputeRemainder(dat, rsDiv)
    if (i < numShortBlocks) dat.push(0)
    blocks.push(dat.concat(eccBytes))
  }
  const result = []
  for (let i = 0; i < blocks[0].length; i++) {
    for (let j = 0; j < blocks.length; j++) {
      if (i !== shortBlockLen - blockEccLen || j >= numShortBlocks) result.push(blocks[j][i])
    }
  }
  return result
}

function drawCodewords(ctx, data) {
  let i = 0
  for (let right = ctx.size - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5
    for (let vert = 0; vert < ctx.size; vert++) {
      for (let j = 0; j < 2; j++) {
        const x = right - j
        const upward = ((right + 1) & 2) === 0
        const y = upward ? ctx.size - 1 - vert : vert
        if (!ctx.isFunction[y][x] && i < data.length * 8) {
          ctx.modules[y][x] = getBit(data[i >>> 3], 7 - (i & 7))
          i++
        }
      }
    }
  }
}

function applyMask(ctx, mask) {
  for (let y = 0; y < ctx.size; y++) {
    for (let x = 0; x < ctx.size; x++) {
      let invert
      if (mask === 0) invert = (x + y) % 2 === 0
      else if (mask === 1) invert = y % 2 === 0
      else if (mask === 2) invert = x % 3 === 0
      else if (mask === 3) invert = (x + y) % 3 === 0
      else if (mask === 4) invert = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0
      else if (mask === 5) invert = x * y % 2 + x * y % 3 === 0
      else if (mask === 6) invert = (x * y % 2 + x * y % 3) % 2 === 0
      else invert = ((x + y) % 2 + x * y % 3) % 2 === 0
      if (!ctx.isFunction[y][x] && invert) ctx.modules[y][x] = !ctx.modules[y][x]
    }
  }
}

function getPenaltyScore(ctx) {
  let result = 0
  for (let y = 0; y < ctx.size; y++) {
    let runColor = false
    let runX = 0
    let runHistory = [0, 0, 0, 0, 0, 0, 0]
    for (let x = 0; x < ctx.size; x++) {
      if (ctx.modules[y][x] === runColor) {
        runX++
        if (runX === 5) result += 3
        else if (runX > 5) result++
      } else {
        finderPenaltyAddHistory(ctx, runX, runHistory)
        if (!runColor) result += finderPenaltyCountPatterns(ctx, runHistory) * 40
        runColor = ctx.modules[y][x]
        runX = 1
      }
    }
    result += finderPenaltyTerminateAndCount(ctx, runColor, runX, runHistory) * 40
  }
  for (let x = 0; x < ctx.size; x++) {
    let runColor = false
    let runY = 0
    let runHistory = [0, 0, 0, 0, 0, 0, 0]
    for (let y = 0; y < ctx.size; y++) {
      if (ctx.modules[y][x] === runColor) {
        runY++
        if (runY === 5) result += 3
        else if (runY > 5) result++
      } else {
        finderPenaltyAddHistory(ctx, runY, runHistory)
        if (!runColor) result += finderPenaltyCountPatterns(ctx, runHistory) * 40
        runColor = ctx.modules[y][x]
        runY = 1
      }
    }
    result += finderPenaltyTerminateAndCount(ctx, runColor, runY, runHistory) * 40
  }
  for (let y = 0; y < ctx.size - 1; y++) {
    for (let x = 0; x < ctx.size - 1; x++) {
      const color = ctx.modules[y][x]
      if (color === ctx.modules[y][x + 1] && color === ctx.modules[y + 1][x] && color === ctx.modules[y + 1][x + 1]) result += 3
    }
  }
  let dark = 0
  for (let y = 0; y < ctx.size; y++) for (let x = 0; x < ctx.size; x++) if (ctx.modules[y][x]) dark++
  const total = ctx.size * ctx.size
  const k = Math.ceil(Math.abs(dark * 20 - total * 10) / total) - 1
  result += k * 10
  return result
}

function finderPenaltyCountPatterns(ctx, runHistory) {
  const n = runHistory[1]
  const core = n > 0 && runHistory[2] === n && runHistory[3] === n * 3 && runHistory[4] === n && runHistory[5] === n
  return (core && runHistory[0] >= n * 4 && runHistory[6] >= n ? 1 : 0) + (core && runHistory[6] >= n * 4 && runHistory[0] >= n ? 1 : 0)
}

function finderPenaltyTerminateAndCount(ctx, currentRunColor, currentRunLength, runHistory) {
  if (currentRunColor) {
    finderPenaltyAddHistory(ctx, currentRunLength, runHistory)
    currentRunLength = 0
  }
  currentRunLength += ctx.size
  finderPenaltyAddHistory(ctx, currentRunLength, runHistory)
  return finderPenaltyCountPatterns(ctx, runHistory)
}

function finderPenaltyAddHistory(ctx, currentRunLength, runHistory) {
  if (runHistory[0] === 0) currentRunLength += ctx.size
  runHistory.pop()
  runHistory.unshift(currentRunLength)
}

function getAlignmentPatternPositions(version, size) {
  if (version === 1) return []
  const numAlign = Math.floor(version / 7) + 2
  const step = Math.floor((version * 8 + numAlign * 3 + 5) / (numAlign * 4 - 4)) * 2
  const result = [6]
  for (let pos = size - 7; result.length < numAlign; pos -= step) result.splice(1, 0, pos)
  return result
}

function getNumRawDataModules(version) {
  let result = (16 * version + 128) * version + 64
  if (version >= 2) {
    const numAlign = Math.floor(version / 7) + 2
    result -= (25 * numAlign - 10) * numAlign - 55
    if (version >= 7) result -= 36
  }
  return result
}

function getNumDataCodewords(version, ecc) {
  return Math.floor(getNumRawDataModules(version) / 8) - ECC_CODEWORDS_PER_BLOCK[ecc][version] * NUM_ERROR_CORRECTION_BLOCKS[ecc][version]
}

function reedSolomonComputeDivisor(degree) {
  const result = []
  for (let i = 0; i < degree - 1; i++) result.push(0)
  result.push(1)
  let root = 1
  for (let i = 0; i < degree; i++) {
    for (let j = 0; j < result.length; j++) {
      result[j] = reedSolomonMultiply(result[j], root)
      if (j + 1 < result.length) result[j] ^= result[j + 1]
    }
    root = reedSolomonMultiply(root, 0x02)
  }
  return result
}

function reedSolomonComputeRemainder(data, divisor) {
  const result = []
  for (let i = 0; i < divisor.length; i++) result.push(0)
  for (let d = 0; d < data.length; d++) {
    const factor = data[d] ^ result.shift()
    result.push(0)
    for (let i = 0; i < divisor.length; i++) result[i] ^= reedSolomonMultiply(divisor[i], factor)
  }
  return result
}

function reedSolomonMultiply(x, y) {
  let z = 0
  for (let i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >>> 7) * 0x11d)
    z ^= ((y >>> i) & 1) * x
  }
  return z
}

function appendBits(val, len, out) {
  for (let i = len - 1; i >= 0; i--) out.push((val >>> i) & 1)
}

function getBit(x, i) {
  return ((x >>> i) & 1) !== 0
}

function toUtf8(str) {
  const out = []
  for (let i = 0; i < str.length; i++) {
    let c = str.charCodeAt(i)
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
      const next = str.charCodeAt(i + 1)
      if (next >= 0xdc00 && next <= 0xdfff) {
        c = 0x10000 + ((c - 0xd800) << 10) + (next - 0xdc00)
        i++
      }
    }
    if (c < 0x80) out.push(c)
    else if (c < 0x800) {
      out.push(0xc0 | (c >> 6))
      out.push(0x80 | (c & 0x3f))
    } else if (c < 0x10000) {
      out.push(0xe0 | (c >> 12))
      out.push(0x80 | ((c >> 6) & 0x3f))
      out.push(0x80 | (c & 0x3f))
    } else {
      out.push(0xf0 | (c >> 18))
      out.push(0x80 | ((c >> 12) & 0x3f))
      out.push(0x80 | ((c >> 6) & 0x3f))
      out.push(0x80 | (c & 0x3f))
    }
  }
  return out
}
