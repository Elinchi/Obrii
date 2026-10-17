// Tests for the UI language selector.
//   node --test plugins/elinchi.wallpaper-editor/test/
const { test } = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")

const I18n = require(path.join(__dirname, "..", "I18n.js"))

test("normalize picks Ukrainian for uk/ua locales and English otherwise", () => {
  for (const locale of ["uk", "uk_UA.UTF-8", "uk-UA", "ua", "ua_UA", "UK_ua"]) {
    assert.equal(I18n.normalize(locale), "uk", locale)
  }
  for (const locale of ["en", "en_US.UTF-8", "C", "de_DE", "ru_RU", "", null, undefined]) {
    assert.equal(I18n.normalize(locale), "en", String(locale))
  }
})

test("both dictionaries define the same keys", () => {
  const en = Object.keys(I18n.dictionaries.en).sort()
  const uk = Object.keys(I18n.dictionaries.uk).sort()
  assert.deepEqual(en, uk)
})

test("translations differ where it matters", () => {
  assert.equal(I18n.t("title.wallpaper", "en"), "Wallpaper")
  assert.equal(I18n.t("title.wallpaper", "uk"), "Шпалери")
  assert.equal(I18n.t("button.apply", "en"), "Apply")
  assert.equal(I18n.t("button.apply", "uk"), "Застосувати")
})

test("unknown keys fall back to the key and to English", () => {
  assert.equal(I18n.t("no.such.key", "en"), "no.such.key")
  assert.equal(I18n.t("title.monitors", "de"), "Monitors")
})

test("format substitutes placeholders", () => {
  const text = I18n.format("warn.refreshMismatch", "en", { expected: "180.00", actual: "59.95" })
  assert.match(text, /180\.00/)
  assert.match(text, /59\.95/)
  assert.ok(text.indexOf("{") === -1)
})
