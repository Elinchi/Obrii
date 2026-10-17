// Wallpaper geometry maths, shared by the renderer (BackgroundPerMonitor.qml)
// and the editor preview (Panel.qml).
//
// Rule zero: this file must never import QtQuick and must never touch a Qt
// type. The editor renders the same monitor at a fraction of its size, so both
// sides feed the same numbers through these functions and only the *screen*
// dimensions differ. Any formula change lands here once and both sides stay in
// lockstep, which is the whole point of the module — the two copies used to
// drift and the preview stopped matching the real monitor.
//
// No `.pragma library`: that pragma makes the file a QML-only singleton and
// breaks `node --test`. These are pure functions, so a per-import copy is fine
// and the same file runs under Node for the aspect-ratio tests.

var MODES = ["crop", "fit", "stretch", "tile"]

var POSITIONS = [
  "center",
  "top",
  "bottom",
  "left",
  "right",
  "top-left",
  "top-right",
  "bottom-left",
  "bottom-right"
]

function num(value, fallback) {
  var n = Number(value)
  return isFinite(n) ? n : fallback
}

function normalizeMode(mode) {
  var m = String(mode == null ? "" : mode)
  return MODES.indexOf(m) >= 0 ? m : "crop"
}

function normalizePosition(position) {
  var p = String(position == null ? "" : position)
  return POSITIONS.indexOf(p) >= 0 ? p : "center"
}

// Horizontal anchor for cover/contain modes once the image size is known.
function alignX(position, screenW, imageW) {
  if (position.indexOf("left") >= 0) return 0
  if (position.indexOf("right") >= 0) return screenW - imageW
  return (screenW - imageW) / 2
}

function alignY(position, screenH, imageH) {
  if (position.indexOf("top") >= 0) return 0
  if (position.indexOf("bottom") >= 0) return screenH - imageH
  return (screenH - imageH) / 2
}

// Resolve the image rectangle for one monitor.
//
//   options = {
//     mode, position,          // see MODES / POSITIONS
//     imageW, imageH,          // natural (source) pixel size
//     screenW, screenH,        // target surface, in the same units as offsets
//     offsetX, offsetY         // user pan, in the same units as screenW/H
//   }
//
// Returns { width, height, x, y }. `stretch` and `tile` fill the surface and
// only move by the offsets; `crop` covers the surface (may overflow) and `fit`
// contains it (may letterbox). Offsets always apply, matching the renderer.
function layout(options) {
  var o = options || {}
  var mode = normalizeMode(o.mode)
  var position = normalizePosition(o.position)
  var screenW = num(o.screenW, 1)
  var screenH = num(o.screenH, 1)
  var imageW = num(o.imageW, 0)
  var imageH = num(o.imageH, 0)
  var offsetX = num(o.offsetX, 0)
  var offsetY = num(o.offsetY, 0)
  if (imageW <= 0) imageW = 1
  if (imageH <= 0) imageH = 1

  if (mode === "stretch" || mode === "tile")
    return { width: screenW, height: screenH, x: offsetX, y: offsetY }

  var scale = mode === "fit"
    ? Math.min(screenW / imageW, screenH / imageH)
    : Math.max(screenW / imageW, screenH / imageH)
  var width = imageW * scale
  var height = imageH * scale
  return {
    width: width,
    height: height,
    x: alignX(position, screenW, width) + offsetX,
    y: alignY(position, screenH, height) + offsetY
  }
}

// Node/CommonJS bridge. QML has no `module`, so the guard is inert there.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    MODES: MODES,
    POSITIONS: POSITIONS,
    num: num,
    normalizeMode: normalizeMode,
    normalizePosition: normalizePosition,
    alignX: alignX,
    alignY: alignY,
    layout: layout
  }
}
