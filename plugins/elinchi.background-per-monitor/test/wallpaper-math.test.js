// Aspect-ratio / mode / position tests for WallpaperMath.js.
//
// Run with:  node --test ~/.config/omarchy/plugins/elinchi.background-per-monitor/test/
//
// The module is intentionally Qt-free (see its header) so these run under plain
// Node. They encode the invariants the renderer relies on: crop must always
// cover the surface (never leave a gap), fit must always stay inside it, and
// stretch/tile must be exactly the surface. The preview calls the identical
// function, so passing here means the two cannot drift.

const { test } = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")

const Math_ = require(path.join(__dirname, "..", "WallpaperMath.js"))

const EPS = 1e-6

function close(actual, expected, msg) {
  assert.ok(Math.abs(actual - expected) <= EPS,
    (msg || "") + " expected " + expected + " got " + actual)
}

// name, imageW, imageH
const IMAGES = [
  ["landscape 16:9", 3840, 2160],
  ["ultrawide 21:9", 3440, 1440],
  ["classic 4:3", 1600, 1200],
  ["portrait 3:4", 1200, 1600],
  ["square", 2000, 2000]
]

// name, screenW, screenH
const SCREENS = [
  ["main 2560x1440 (16:9)", 2560, 1440],
  ["dell portrait 1200x1920", 1200, 1920],
  ["ultrawide 3440x1440 (21:9)", 3440, 1440],
  ["4:3 1600x1200", 1600, 1200]
]

test("crop always covers the surface for every aspect pair", () => {
  for (const [iname, iw, ih] of IMAGES) {
    for (const [sname, sw, sh] of SCREENS) {
      const g = Math_.layout({ mode: "crop", position: "center", imageW: iw, imageH: ih, screenW: sw, screenH: sh })
      assert.ok(g.width >= sw - EPS, `crop ${iname} on ${sname}: width ${g.width} < ${sw}`)
      assert.ok(g.height >= sh - EPS, `crop ${iname} on ${sname}: height ${g.height} < ${sh}`)
      // centred: overflow split evenly
      close(g.x, (sw - g.width) / 2, `crop ${iname} on ${sname} x`)
      close(g.y, (sh - g.height) / 2, `crop ${iname} on ${sname} y`)
    }
  }
})

test("fit always stays inside the surface for every aspect pair", () => {
  for (const [iname, iw, ih] of IMAGES) {
    for (const [sname, sw, sh] of SCREENS) {
      const g = Math_.layout({ mode: "fit", position: "center", imageW: iw, imageH: ih, screenW: sw, screenH: sh })
      assert.ok(g.width <= sw + EPS, `fit ${iname} on ${sname}: width ${g.width} > ${sw}`)
      assert.ok(g.height <= sh + EPS, `fit ${iname} on ${sname}: height ${g.height} > ${sh}`)
    }
  }
})

test("stretch and tile fill the surface exactly", () => {
  for (const mode of ["stretch", "tile"]) {
    for (const [iname, iw, ih] of IMAGES) {
      const g = Math_.layout({ mode, position: "bottom-right", imageW: iw, imageH: ih, screenW: 1920, screenH: 1080 })
      close(g.width, 1920, `${mode} ${iname} width`)
      close(g.height, 1080, `${mode} ${iname} height`)
      close(g.x, 0, `${mode} ${iname} x`)
      close(g.y, 0, `${mode} ${iname} y`)
    }
  }
})

test("aspect ratio is preserved for crop and fit", () => {
  for (const mode of ["crop", "fit"]) {
    for (const [iname, iw, ih] of IMAGES) {
      const g = Math_.layout({ mode, position: "center", imageW: iw, imageH: ih, screenW: 2560, screenH: 1440 })
      close(g.width / g.height, iw / ih, `${mode} ${iname} aspect`)
    }
  }
})

test("position anchors crop/fit correctly", () => {
  const iw = 1000, ih = 500, sw = 400, sh = 400 // image wider than square screen
  const g = (position) => Math_.layout({ mode: "crop", position, imageW: iw, imageH: ih, screenW: sw, screenH: sh })
  close(g("left").x, 0, "left")
  close(g("right").x, sw - g("right").width, "right")
  close(g("center").x, (sw - g("center").width) / 2, "center")
  close(g("top").y, 0, "top")
  close(g("bottom").y, sh - g("bottom").height, "bottom")
  close(g("top-left").x, 0, "top-left x")
  close(g("top-left").y, 0, "top-left y")
  close(g("bottom-right").x, sw - g("bottom-right").width, "bottom-right x")
  close(g("bottom-right").y, sh - g("bottom-right").height, "bottom-right y")
})

test("offsets shift the rectangle in every mode, in surface units", () => {
  for (const mode of ["crop", "fit", "stretch", "tile"]) {
    const base = Math_.layout({ mode, position: "center", imageW: 2000, imageH: 1000, screenW: 1920, screenH: 1080 })
    const moved = Math_.layout({ mode, position: "center", imageW: 2000, imageH: 1000, screenW: 1920, screenH: 1080, offsetX: 30, offsetY: -40 })
    close(moved.x, base.x + 30, `${mode} offset x`)
    close(moved.y, base.y - 40, `${mode} offset y`)
    close(moved.width, base.width, `${mode} offset keeps width`)
    close(moved.height, base.height, `${mode} offset keeps height`)
  }
})

test("unknown mode/position fall back to safe defaults", () => {
  const g = Math_.layout({ mode: "bogus", position: "nowhere", imageW: 1600, imageH: 1200, screenW: 1920, screenH: 1080 })
  // "crop" + "center"
  assert.ok(g.width >= 1920 - EPS && g.height >= 1080 - EPS)
  close(g.x, (1920 - g.width) / 2, "fallback centre x")
})

test("preview scaling is proportional: same ratios at any surface size", () => {
  // The editor draws the monitor at a fraction of its size. Feeding the same
  // image through a smaller surface with proportionally smaller offsets must
  // yield the same *relative* rectangle — this is the exact drift that used to
  // make the preview disagree with the real monitor.
  const imageW = 3440, imageH = 1440
  const cases = [
    { mode: "crop", position: "bottom-right", offsetX: 120, offsetY: -80 },
    { mode: "fit", position: "top-left", offsetX: -50, offsetY: 30 },
    { mode: "stretch", position: "center", offsetX: 10, offsetY: 10 }
  ]
  for (const c of cases) {
    const real = Math_.layout({ ...c, imageW, imageH, screenW: 2560, screenH: 1440 })
    const k = 0.25
    const preview = Math_.layout({
      mode: c.mode,
      position: c.position,
      imageW,
      imageH,
      screenW: 2560 * k,
      screenH: 1440 * k,
      offsetX: c.offsetX * k,
      offsetY: c.offsetY * k
    })
    close(preview.width, real.width * k, `${c.mode} preview width`)
    close(preview.height, real.height * k, `${c.mode} preview height`)
    close(preview.x, real.x * k, `${c.mode} preview x`)
    close(preview.y, real.y * k, `${c.mode} preview y`)
  }
})

test("a missing/zero image size never divides by zero", () => {
  const g = Math_.layout({ mode: "crop", position: "center", imageW: 0, imageH: 0, screenW: 1920, screenH: 1080 })
  assert.ok(isFinite(g.width) && isFinite(g.height) && isFinite(g.x) && isFinite(g.y))
  const z = Math_.layout({ mode: "fit", position: "center", imageW: undefined, imageH: null, screenW: 1920, screenH: 1080 })
  assert.ok(isFinite(z.width) && isFinite(z.height))
})
