// UI strings for the wallpaper editor. No Qt imports so the file also parses
// under plain Node (the test for WallpaperMath does not need it, but keeping
// the module pure makes linting trivial).
//
// Language selection is automatic: WALLPAPER_EDITOR_LANG overrides, otherwise
// LC_ALL / LANG decide, otherwise English. Ukrainian is chosen for uk*/ua*
// locales; everything else falls back to English.

var dictionaries = {
  en: {
    "title.wallpaper": "Wallpaper",
    "title.monitors": "Monitors",
    "subtitle.wallpaper": "Pick a monitor and drag the image to frame it",
    "subtitle.monitors": "Resolution, refresh rate, scale and display layout",
    "tab.wallpaper": "Wallpaper",
    "tab.monitors": "Monitors",

    "monitor.primary": "Primary",
    "monitor.landscape": "Landscape",
    "monitor.portrait": "Portrait",
    "monitor.count.one": "display",
    "monitor.count.many": "displays",

    "wallpaper.themeGlobal": "Theme wallpaper",
    "badge.own": "OWN",
    "badge.globalMoved": "GLOBAL · MOVED",
    "badge.global": "GLOBAL",
    "preview.empty": "Pick an image",
    "preview.hint": "Drag the image in the frame or use the X and Y sliders",

    "mode.label": "Scaling",
    "mode.crop": "Fill screen",
    "mode.fit": "Fit",
    "mode.stretch": "Stretch",
    "mode.tile": "Tile",

    "position.label": "Position",
    "position.center": "Center",
    "position.top": "Top",
    "position.bottom": "Bottom",
    "position.left": "Left",
    "position.right": "Right",
    "position.topLeft": "Top left",
    "position.topRight": "Top right",
    "position.bottomLeft": "Bottom left",
    "position.bottomRight": "Bottom right",

    "offset.x": "Offset X",
    "offset.y": "Offset Y",
    "offset.resetX": "Reset X to 0",
    "offset.resetY": "Reset Y to 0",

    "status.busy": "Applying…",
    "status.ownWallpaper": "Custom wallpaper for this monitor",
    "status.globalMoved": "Theme wallpaper with a custom frame",
    "status.global": "Using the theme wallpaper",

    "layout.title": "Display layout",
    "layout.hint": "Drag a display on the map. Coordinates are relative to its top-left corner.",

    "display.resolution": "Resolution",
    "display.refresh": "Refresh rate",
    "display.scale": "Scale",
    "display.resetScale": "Reset scale",
    "display.orientation": "Orientation",
    "display.x": "Position X",
    "display.y": "Position Y",

    "orientation.0": "Normal",
    "orientation.1": "Rotate 90°",
    "orientation.2": "Rotate 180°",
    "orientation.3": "Rotate 270°",
    "orientation.4": "Mirror",
    "orientation.5": "Mirror + 90°",
    "orientation.6": "Mirror + 180°",
    "orientation.7": "Mirror + 270°",

    "button.wait": "Please wait…",
    "button.chooseImage": "Choose image…",
    "button.changeTheme": "Change theme…",
    "button.addThemeImage": "Add image to theme…",
    "button.resetMonitor": "Reset for monitor",
    "button.done": "Done",
    "button.refreshList": "Refresh list",
    "button.apply": "Apply",

    "status.displayBusy": "Applying and saving…",
    "status.displayDirty": "Unsaved changes",
    "status.displayClean": "New displays are added automatically",

    "theme.caption": "THEME",
    "theme.currentHint": "Your current theme",
    "status.themeImageAdded": "Added to the theme: {name}",
    "error.addThemeImage": "Could not add the image to the theme: {detail}",

    "error.unsavedMonitor": "Apply or discard this monitor's pending changes first.",
    "error.configRead": "Could not read the wallpaper configuration: {detail}",
    "error.monitorsRead": "Could not read the monitor list: {detail}",
    "error.monitorsList": "Could not get the monitor list (hyprctl exit {code}).",
    "error.configLoad": "Could not load the configuration (cat exit {code}).",
    "error.applyDisplay": "Could not apply the monitor settings.",
    "error.applyChange": "Could not apply the change. Check the file path and try again.",
    "error.selectWallpaperPrefix": "Could not choose the wallpaper: {detail}",
    "error.selectWallpaper": "Could not open the wallpaper picker.",
    "error.globalPrefix": "Could not change the theme wallpaper: {detail}",
    "error.global": "Could not change the theme wallpaper.",
    "warn.refreshMismatch": "Requested {expected} Hz, but Hyprland reports {actual} Hz. The refresh rate was not applied — check the mode."
  },

  uk: {
    "title.wallpaper": "Шпалери",
    "title.monitors": "Монітори",
    "subtitle.wallpaper": "Вибери монітор і перетягни зображення, щоб підлаштувати кадр",
    "subtitle.monitors": "Роздільність, частота, масштаб і розташування дисплеїв",
    "tab.wallpaper": "Шпалери",
    "tab.monitors": "Монітори",

    "monitor.primary": "Головний",
    "monitor.landscape": "Альбомний",
    "monitor.portrait": "Портретний",
    "monitor.count.one": "дисплей",
    "monitor.count.many": "дисплеї",

    "wallpaper.themeGlobal": "Загальні шпалери теми",
    "badge.own": "ОКРЕМІ",
    "badge.globalMoved": "ЗАГАЛЬНІ · ЗМІЩЕНО",
    "badge.global": "ЗАГАЛЬНІ",
    "preview.empty": "Вибери зображення",
    "preview.hint": "Перетягни зображення в рамці або скористайся повзунками X та Y",

    "mode.label": "Масштабування",
    "mode.crop": "Заповнити екран",
    "mode.fit": "Вмістити повністю",
    "mode.stretch": "Розтягнути",
    "mode.tile": "Замостити",

    "position.label": "Позиція",
    "position.center": "Центр",
    "position.top": "Верх",
    "position.bottom": "Низ",
    "position.left": "Ліво",
    "position.right": "Право",
    "position.topLeft": "Верх-ліво",
    "position.topRight": "Верх-право",
    "position.bottomLeft": "Низ-ліво",
    "position.bottomRight": "Низ-право",

    "offset.x": "Положення X",
    "offset.y": "Положення Y",
    "offset.resetX": "Скинути X до 0",
    "offset.resetY": "Скинути Y до 0",

    "status.busy": "Застосовую…",
    "status.ownWallpaper": "Окремі шпалери для цього монітора",
    "status.globalMoved": "Загальна шпалера теми з окремим кадром",
    "status.global": "Використовуються загальні шпалери",

    "layout.title": "Розташування екранів",
    "layout.hint": "Перетягни дисплей на схемі. Координати задаються відносно його лівого верхнього кута.",

    "display.resolution": "Роздільність",
    "display.refresh": "Частота",
    "display.scale": "Масштаб",
    "display.resetScale": "Скинути масштаб",
    "display.orientation": "Орієнтація",
    "display.x": "Позиція X",
    "display.y": "Позиція Y",

    "orientation.0": "Звичайна",
    "orientation.1": "Поворот 90°",
    "orientation.2": "Поворот 180°",
    "orientation.3": "Поворот 270°",
    "orientation.4": "Віддзеркалити",
    "orientation.5": "Віддзеркалити + 90°",
    "orientation.6": "Віддзеркалити + 180°",
    "orientation.7": "Віддзеркалити + 270°",

    "button.wait": "Зачекай…",
    "button.chooseImage": "Вибрати зображення…",
    "button.changeTheme": "Змінити тему…",
    "button.addThemeImage": "Додати зображення до теми…",
    "button.resetMonitor": "Скинути для монітора",
    "button.done": "Готово",
    "button.refreshList": "Оновити список",
    "button.apply": "Застосувати",

    "status.displayBusy": "Застосовую й зберігаю…",
    "status.displayDirty": "Є незбережені зміни",
    "status.displayClean": "Нові дисплеї додаються автоматично",

    "theme.caption": "ТЕМА",
    "theme.currentHint": "Ваша поточна тема",
    "status.themeImageAdded": "Додано до теми: {name}",
    "error.addThemeImage": "Не вдалося додати зображення до теми: {detail}",

    "error.unsavedMonitor": "Спочатку застосуй або скасуй незбережені параметри цього монітора.",
    "error.configRead": "Не вдалося прочитати налаштування шпалер: {detail}",
    "error.monitorsRead": "Не вдалося прочитати список моніторів: {detail}",
    "error.monitorsList": "Не вдалося отримати список моніторів (hyprctl exit {code}).",
    "error.configLoad": "Не вдалося завантажити конфігурацію (cat exit {code}).",
    "error.applyDisplay": "Не вдалося застосувати параметри монітора.",
    "error.applyChange": "Не вдалося застосувати зміну. Перевір шлях до файлу та спробуй ще раз.",
    "error.selectWallpaperPrefix": "Не вдалося вибрати шпалеру: {detail}",
    "error.selectWallpaper": "Не вдалося відкрити вибір шпалер.",
    "error.globalPrefix": "Не вдалося змінити загальні шпалери: {detail}",
    "error.global": "Не вдалося змінити загальні шпалери.",
    "warn.refreshMismatch": "Обрано {expected} Hz, але Hyprland повідомляє {actual} Hz. Частоту не застосовано — перевір режим."
  }
}

function normalize(tag) {
  var text = String(tag == null ? "" : tag).trim().toLowerCase()
  if (text === "uk" || text === "ua") return "uk"
  // Match uk_UA, uk-UA, and the legacy *_UA forms such as ru_UA? RU_UA is not
  // Ukrainian, so only accept an explicit uk prefix or a plain ua tag.
  if (text.indexOf("uk_") === 0 || text.indexOf("uk-") === 0) return "uk"
  if (text.indexOf("ua_") === 0 || text.indexOf("ua-") === 0) return "uk"
  return "en"
}

function t(key, lang) {
  var code = normalize(lang)
  var table = dictionaries[code] || dictionaries.en
  if (table[key] !== undefined) return table[key]
  if (dictionaries.en[key] !== undefined) return dictionaries.en[key]
  return key
}

function format(key, lang, vars) {
  var text = t(key, lang)
  if (!vars) return text
  for (var name in vars) {
    text = text.split("{" + name + "}").join(String(vars[name]))
  }
  return text
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { dictionaries: dictionaries, normalize: normalize, t: t, format: format }
}
