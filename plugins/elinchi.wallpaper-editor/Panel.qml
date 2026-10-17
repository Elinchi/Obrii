import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

import "../elinchi.background-per-monitor/WallpaperMath.js" as WallpaperMath
import "I18n.js" as I18n

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  // Auto: explicit override, then the session locale. English is the fallback.
  readonly property string language: I18n.normalize(
    Quickshell.env("WALLPAPER_EDITOR_LANG") || Quickshell.env("LC_ALL")
    || Quickshell.env("LANG") || Qt.locale().name)
  function tr(key) { return I18n.t(key, language) }
  function trf(key, vars) { return I18n.format(key, language, vars) }
  property bool busy: false
  property bool dragging: false
  property string errorText: ""
  property string configError: ""
  property string statusMessage: ""
  property string currentTheme: ""
  property var pendingOffsets: null
  property string selectedMonitor: ""
  property string globalWallpaper: ""
  property var monitors: []
  property var configs: ({})
  property int offsetX: 0
  property int offsetY: 0
  property string currentMode: "crop"
  property string currentPosition: "center"
  property string activeTab: "wallpaper"
  property string selectedDisplayMode: ""
  property string selectedResolution: ""
  property string selectedRefresh: ""
  property real displayScale: 1
  property int displayTransform: 0
  property int displayX: 0
  property int displayY: 0
  property bool displayBusy: false
  property bool displayDirty: false
  property string displayError: ""
  property string displayWarning: ""
  property string verifyRefreshMonitor: ""
  property real verifyRefreshExpected: 0
  property real layoutScale: 0.06
  property real layoutMinX: 0
  property real layoutMinY: 0
  property real layoutWidth: 1
  property real layoutHeight: 1
  readonly property var selectedInfo: infoFor(selectedMonitor)
  readonly property var selectedConfig: configs[selectedMonitor] || ({})
  readonly property bool hasMonitorOverride: Object.keys(selectedConfig).length > 0
  readonly property string selectedWallpaper: selectedConfig.wallpaper || globalWallpaper || ""
  readonly property real previewScaleX: previewCanvas.width / Math.max(1, selectedInfo.logicalWidth || 1)
  readonly property real previewScaleY: previewCanvas.height / Math.max(1, selectedInfo.logicalHeight || 1)
  readonly property real selectedAspect: (selectedInfo.logicalWidth || 16) / Math.max(1, selectedInfo.logicalHeight || 9)

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    selectedMonitor = payload.monitor ? String(payload.monitor) : ""
    activeTab = payload.tab === "monitors" ? "monitors" : "wallpaper"
    opened = true
    errorText = ""
    statusMessage = ""
    loadMonitorsProc.running = true
    readConfigProc.running = true
    readGlobalProc.running = true
  }

  function close() { opened = false }

  function dismiss() {
    if (shell && typeof shell.hide === "function")
      shell.hide((manifest && manifest.id) || "elinchi.wallpaper-editor")
    else close()
  }

  function infoFor(name) {
    for (var i = 0; i < monitors.length; i++)
      if (monitors[i].name === name) return monitors[i]
    return { name: name, logicalWidth: 16, logicalHeight: 9, width: 16, height: 9,
      scale: 1, transform: 0, refreshRate: 60, x: 0, y: 0, availableModes: [], focused: false }
  }

  function setMonitor(name) {
    if (activeTab === "monitors" && displayDirty && name !== selectedMonitor) {
      displayError = root.tr("error.unsavedMonitor")
      return false
    }
    selectedMonitor = name
    displayWarning = ""
    verifyRefreshMonitor = ""
    loadMonitorValues()
    loadDisplaySettings(infoFor(name))
    return true
  }

  function modeText(mode) { return String(mode || "").replace(/Hz$/, "") }

  function resolutionOptions(name) {
    var m = infoFor(name), out = []
    for (var i = 0; i < m.availableModes.length; i++) {
      var parts = modeText(m.availableModes[i]).split("@")
      if (parts.length !== 2 || out.indexOf(parts[0]) >= 0) continue
      out.push(parts[0])
    }
    return out
  }

  function refreshOptions(name, resolution) {
    var m = infoFor(name), out = []
    for (var i = 0; i < m.availableModes.length; i++) {
      var parts = modeText(m.availableModes[i]).split("@")
      if (parts.length !== 2 || parts[0] !== resolution) continue
      var hz = Number(parts[1]).toFixed(2)
      if (out.indexOf(hz) < 0) out.push(hz)
    }
    out.sort(function(a, b) { return Number(b) - Number(a) })
    return out
  }

  function loadDisplaySettings(m) {
    if (!m || !m.name) return
    var width = Number(m.width || 0), height = Number(m.height || 0)
    selectedResolution = width + "x" + height
    selectedRefresh = Number(m.refreshRate || 60).toFixed(2)
    selectedDisplayMode = selectedResolution + "@" + selectedRefresh
    displayScale = Number(m.scale || 1)
    displayTransform = Number(m.transform || 0)
    displayX = Math.round(Number(m.x || 0))
    displayY = Math.round(Number(m.y || 0))
    displayDirty = false
    displayError = ""
    updateLayoutBounds()
  }

  function defaultDisplayScale(name) {
    var description = String(infoFor(name).description || "").toLowerCase()
    if (description.indexOf("u2415") !== -1) return 0.8333333
    return 1
  }

  function resetDisplayScale() {
    displayScale = nearestValidScale(defaultDisplayScale(selectedMonitor))
    displayDirty = true
    displayError = ""
    updateLayoutBounds()
  }

  function displayTileSize(m) {
    if (m.name !== selectedMonitor) return { width: m.logicalWidth, height: m.logicalHeight }
    var parts = selectedResolution.split("x")
    if (parts.length !== 2) return { width: m.logicalWidth, height: m.logicalHeight }
    var w = Number(parts[0]), h = Number(parts[1])
    if (displayTransform % 2) { var swap = w; w = h; h = swap }
    return { width: Math.round(w / displayScale), height: Math.round(h / displayScale) }
  }

  function monitorTileWidth(m) { return displayTileSize(m).width }
  function monitorTileHeight(m) { return displayTileSize(m).height }

  function nearestValidScale(value) {
    var parts = selectedResolution.split("x")
    if (parts.length !== 2) return Number(value)
    var a = Number(parts[0]), b = Number(parts[1])
    var x = a, y = b
    while (y) { var r = x % y; x = y; y = r }
    var common = x, center = Math.round(common / Number(value)), best = Number(value), distance = Infinity
    for (var k = Math.max(1, center - 2); k <= center + 2; k++) {
      var candidate = common / k
      if (candidate < 0.5 || candidate > 2) continue
      if (Math.abs(a / candidate - Math.round(a / candidate)) > 0.01 || Math.abs(b / candidate - Math.round(b / candidate)) > 0.01) continue
      if (Math.abs(candidate - value) < distance) { best = candidate; distance = Math.abs(candidate - value) }
    }
    return distance === Infinity ? Number(value) : best
  }

  function updateLayoutBounds() {
    if (!monitors.length) return
    var minX = 0, minY = 0, maxX = 1, maxY = 1
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i]
      var mx = m.name === selectedMonitor ? displayX : Number(m.x || 0)
      var my = m.name === selectedMonitor ? displayY : Number(m.y || 0)
      minX = Math.min(minX, mx); minY = Math.min(minY, my)
      var tileSize = displayTileSize(m)
      maxX = Math.max(maxX, mx + tileSize.width)
      maxY = Math.max(maxY, my + tileSize.height)
    }
    layoutMinX = minX; layoutMinY = minY
    layoutWidth = Math.max(1, maxX - minX); layoutHeight = Math.max(1, maxY - minY)
    layoutScale = Math.max(0.01, Math.min((layoutCanvas.width - 32) / layoutWidth, (layoutCanvas.height - 32) / layoutHeight))
  }

  function monitorTileX(m) {
    return 16 + ((m.name === selectedMonitor ? displayX : Number(m.x || 0)) - layoutMinX) * layoutScale
  }

  function monitorTileY(m) {
    return 16 + ((m.name === selectedMonitor ? displayY : Number(m.y || 0)) - layoutMinY) * layoutScale
  }

  function applyDisplaySettings() {
    if (displayBusy || !selectedMonitor || !selectedDisplayMode) return
    displayError = ""
    displayWarning = ""
    displayBusy = true
    verifyRefreshMonitor = selectedMonitor
    verifyRefreshExpected = Number(selectedRefresh)
    displaySettingsProc.command = ["omarchy-monitor-control", "apply", selectedMonitor, selectedDisplayMode,
      String(displayX), String(displayY), String(displayScale), String(displayTransform)]
    displaySettingsProc.running = true
  }

  // Compare the freshly re-read hyprctl state against the requested refresh
  // rate. Runs once per apply; the backend already rejects mismatches, but this
  // catches the cases where Hyprland accepts the mode and quietly falls back to
  // a neighbouring rate.
  function verifyAppliedRefresh(m) {
    if (!m || !verifyRefreshMonitor || m.name !== verifyRefreshMonitor) return
    var actual = Number(m.refreshRate || 0)
    var expected = Number(verifyRefreshExpected)
    if (Math.abs(actual - expected) > 0.5) {
      displayWarning = root.trf("warn.refreshMismatch", {
        expected: expected.toFixed(2),
        actual: actual.toFixed(2)
      })
    } else {
      displayWarning = ""
    }
    verifyRefreshMonitor = ""
  }

  function selectResolution(value) {
    selectedResolution = value
    var rates = refreshOptions(selectedMonitor, value)
    selectedRefresh = rates.length ? rates[0] : "60.00"
    selectedDisplayMode = selectedResolution + "@" + selectedRefresh
    displayScale = nearestValidScale(displayScale)
    displayDirty = true
    updateLayoutBounds()
  }

  function selectRefresh(value) {
    selectedRefresh = value
    selectedDisplayMode = selectedResolution + "@" + selectedRefresh
    displayDirty = true
  }

  function loadMonitorValues() {
    var c = configs[selectedMonitor] || ({})
    offsetX = Number(c.offset_x || 0)
    offsetY = Number(c.offset_y || 0)
    currentMode = String(c.mode || "crop")
    currentPosition = String(c.position || "center")
  }

  function loadConfig(raw) {
    try {
      var data = JSON.parse(raw || "{}")
      configs = data.monitors || ({})
      if (!selectedMonitor && monitors.length) selectedMonitor = monitors[0].name
      loadMonitorValues()
      // A successful read must not wipe an error raised by the last action;
      // action errors are cleared at the start of the next action instead.
      configError = ""
    } catch (e) {
      configError = root.trf("error.configRead", { detail: e })
      debugLog("error", "config parse failed: " + e)
    }
  }

  function parseMonitors(raw) {
    try {
      var list = JSON.parse(raw || "[]")
      var normalized = []
      for (var i = 0; i < list.length; i++) {
        var m = list[i]
        var scale = Number(m.scale || 1)
        var rotated = Number(m.transform || 0) % 2 === 1
        normalized.push({
          name: String(m.name),
          logicalWidth: Math.round((rotated ? m.height : m.width) / scale),
          logicalHeight: Math.round((rotated ? m.width : m.height) / scale),
          width: Number(m.width || 0),
          height: Number(m.height || 0),
          refreshRate: Number(m.refreshRate || 60),
          x: Number(m.x || 0),
          y: Number(m.y || 0),
          availableModes: Array.isArray(m.availableModes) ? m.availableModes : [],
          scale: scale,
          transform: Number(m.transform || 0),
          focused: Boolean(m.focused),
          description: String(m.description || m.model || "")
        })
      }
      normalized.sort(function(a, b) {
        if (a.name === "DP-3") return -1
        if (b.name === "DP-3") return 1
        if (a.focused !== b.focused) return a.focused ? -1 : 1
        return a.name.localeCompare(b.name)
      })
      monitors = normalized
      if (!selectedMonitor || !monitorExists(selectedMonitor)) {
        var primary = normalized.find(function(m) { return m.name === "DP-3" })
        if (!primary) primary = normalized.find(function(m) { return m.focused })
        selectedMonitor = primary ? primary.name : (normalized.length ? normalized[0].name : "")
      }
      loadMonitorValues()
      if (!displayDirty && !displayBusy) loadDisplaySettings(infoFor(selectedMonitor))
      else updateLayoutBounds()
      if (verifyRefreshMonitor) verifyAppliedRefresh(infoFor(verifyRefreshMonitor))
    } catch (e) {
      errorText = root.trf("error.monitorsRead", { detail: e })
      debugLog("error", "monitors parse failed: " + e)
    }
  }

  function monitorExists(name) {
    for (var i = 0; i < monitors.length; i++) if (monitors[i].name === name) return true
    return false
  }

  function runCommand(args) {
    if (commandProc.running) return
    errorText = ""
    statusMessage = ""
    busy = true
    commandProc.command = args
    commandProc.running = true
  }

  function saveOffsetX(value) {
    offsetX = Math.round(Number(value))
    runCommand(["omarchy-per-monitor-bg", "set-offset-x", selectedMonitor, String(offsetX)])
  }

  function saveOffsetY(value) {
    offsetY = Math.round(Number(value))
    runCommand(["omarchy-per-monitor-bg", "set-offset-y", selectedMonitor, String(offsetY)])
  }

  function saveOffsets(x, y) {
    offsetX = Math.round(Number(x))
    offsetY = Math.round(Number(y))
    var args = ["omarchy-per-monitor-bg", "set-offsets", selectedMonitor, String(offsetX), String(offsetY)]
    // A release can land while the previous save is still in flight. Dropping
    // it would make the preview snap back, so remember it and replay on exit.
    if (commandProc.running) {
      pendingOffsets = args
      return
    }
    runCommand(args)
  }

  function savePosition(value) {
    currentPosition = String(value)
    runCommand(["omarchy-per-monitor-bg", "set-position", selectedMonitor, currentPosition])
  }

  // Open Omarchy's built-in theme picker and apply the chosen theme. The
  // switcher only prints the selection; omarchy-theme-set applies it and drives
  // the background/theme IPC, which in turn runs our sync-theme.
  //
  // The panel stays open: the picker is a later Overlay/Exclusive surface (the
  // same as the wallpaper image-selector) and takes keyboard focus itself. The
  // command must be detached because theme-set runs past this call, and any
  // Process owned by the panel would die if the panel were unloaded.
  function changeTheme() {
    debugLog("info", "opening theme switcher")
    Quickshell.execDetached(["bash", "-lc",
      'theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set "$theme"'])
  }

  function imageUrl(path) { return path ? Util.fileUrl(path) : "" }

  // Turn a backend's stderr into a user-facing message. With
  // WALLPAPER_EDITOR_DEBUG=1 the same stream also carries `[wallpaper-editor]`
  // trace lines; those must not surface as errors, so they are dropped.
  function backendMessage(raw) {
    var lines = String(raw || "").trim().split("\n")
    var out = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      if (line.indexOf("[wallpaper-editor]") === 0) continue
      out.push(line)
    }
    return out.join("\n")
  }

  // UI-side events go through the same log file as the backends so a report
  // can be traced end to end. execDetached keeps logging non-blocking: a
  // single Process would drop messages while a previous one is still running.
  function debugLog(level, message) {
    Quickshell.execDetached(["omarchy-per-monitor-bg", "log", String(level), String(message)])
  }

  readonly property var modeOptions: [
    { value: "crop", label: root.tr("mode.crop") },
    { value: "fit", label: root.tr("mode.fit") },
    { value: "stretch", label: root.tr("mode.stretch") },
    { value: "tile", label: root.tr("mode.tile") }
  ]
  readonly property var positionOptions: [
    { value: "center", label: root.tr("position.center") },
    { value: "top", label: root.tr("position.top") },
    { value: "bottom", label: root.tr("position.bottom") },
    { value: "left", label: root.tr("position.left") },
    { value: "right", label: root.tr("position.right") },
    { value: "top-left", label: root.tr("position.topLeft") },
    { value: "top-right", label: root.tr("position.topRight") },
    { value: "bottom-left", label: root.tr("position.bottomLeft") },
    { value: "bottom-right", label: root.tr("position.bottomRight") }
  ]
  readonly property var orientationOptions: [
    { value: "0", label: root.tr("orientation.0") },
    { value: "1", label: root.tr("orientation.1") },
    { value: "2", label: root.tr("orientation.2") },
    { value: "3", label: root.tr("orientation.3") },
    { value: "4", label: root.tr("orientation.4") },
    { value: "5", label: root.tr("orientation.5") },
    { value: "6", label: root.tr("orientation.6") },
    { value: "7", label: root.tr("orientation.7") }
  ]
  readonly property var monitorOptions: monitors.map(function(m) {
    return { value: m.name, label: m.name + (m.name === "DP-3" ? " · " + root.tr("monitor.primary") : "") }
  })

  FileView {
    id: themeNameView
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.currentTheme = String(text() || "").trim()
    onFileChanged: reload()
    onLoadFailed: root.currentTheme = ""
  }

  Process {
    id: loadMonitorsProc
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseMonitors(String(text || "[]")) }
    onExited: function(code) { if (code !== 0) root.configError = root.trf("error.monitorsList", { code: code }) }
  }

  Timer {
    interval: 2500
    repeat: true
    running: root.opened
    onTriggered: {
      if (!root.busy && !root.dragging && !root.displayDirty && !root.displayBusy) {
        if (!loadMonitorsProc.running) loadMonitorsProc.running = true
        if (!readConfigProc.running) readConfigProc.running = true
        if (!readGlobalProc.running) readGlobalProc.running = true
      }
    }
  }

  Process {
    id: displaySettingsProc
    command: []
    property string failureText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(String(text || "{}"))
          if (result.ok) root.displayError = ""
        } catch (e) {}
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: displaySettingsProc.failureText = root.backendMessage(String(text || ""))
    }
    onExited: function(code) {
      root.displayBusy = false
      if (code === 0) {
        root.displayError = ""
        root.displayDirty = false
        root.errorText = ""
        loadMonitorsProc.running = true
      } else {
        root.verifyRefreshMonitor = ""
        root.displayError = displaySettingsProc.failureText || root.tr("error.applyDisplay")
        root.debugLog("error", "display-apply failed: " + root.displayError)
      }
      displaySettingsProc.failureText = ""
    }
  }

  Process {
    id: readConfigProc
    command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/backgrounds-per-monitor.json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.loadConfig(String(text || "{}")) }
    onExited: function(code) { if (code !== 0) root.configError = root.trf("error.configLoad", { code: code }) }
  }

  Process {
    id: readGlobalProc
    command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.globalWallpaper = String(text || "").trim()
    }
  }

  Process {
    id: commandProc
    command: []
    property string failureText: ""
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: commandProc.failureText = root.backendMessage(String(text || ""))
    }
    onExited: function(code) {
      root.busy = false
      if (code === 0) {
        commandProc.failureText = ""
        readConfigProc.running = true
        readGlobalProc.running = true
      } else {
        var detail = commandProc.failureText
        root.errorText = detail || root.tr("error.applyChange")
        root.debugLog("error", "wallpaper-command failed: " + root.errorText)
      }
      if (root.pendingOffsets) {
        var next = root.pendingOffsets
        root.pendingOffsets = null
        root.runCommand(next)
      }
    }
  }

  Process {
    id: chooseMonitorProc
    command: []
    property string failureText: ""
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: chooseMonitorProc.failureText = root.backendMessage(String(text || ""))
    }
    onExited: function(code) {
      root.busy = false
      if (code === 0) {
        chooseMonitorProc.failureText = ""
        readConfigProc.running = true
        readGlobalProc.running = true
      } else {
        var detail = chooseMonitorProc.failureText
        root.errorText = detail ? root.trf("error.selectWallpaperPrefix", { detail: detail }) : root.tr("error.selectWallpaper")
        root.debugLog("error", "wallpaper-select failed: " + root.errorText)
      }
    }
  }

  Process {
    id: chooseGlobalProc
    command: ["omarchy-per-monitor-bg", "select-global"]
    property string failureText: ""
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: chooseGlobalProc.failureText = root.backendMessage(String(text || ""))
    }
    onRunningChanged: if (running) root.busy = true
    onExited: function(code) {
      root.busy = false
      if (code === 0) {
        chooseGlobalProc.failureText = ""
        readConfigProc.running = true
        readGlobalProc.running = true
      } else {
        var detail = chooseGlobalProc.failureText
        root.errorText = detail ? root.trf("error.globalPrefix", { detail: detail }) : root.tr("error.global")
        root.debugLog("error", "global-wallpaper failed: " + root.errorText)
      }
    }
  }

  Process {
    id: themeImageProc
    command: ["omarchy-per-monitor-bg", "add-theme-image"]
    property string addedPath: ""
    property string failureText: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: themeImageProc.addedPath = String(text || "").trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: themeImageProc.failureText = root.backendMessage(String(text || ""))
    }
    onExited: function(code) {
      root.busy = false
      if (code === 0) {
        if (themeImageProc.addedPath) {
          var name = themeImageProc.addedPath.split("/").pop()
          root.statusMessage = root.trf("status.themeImageAdded", { name: name })
          root.debugLog("info", "theme image added: " + themeImageProc.addedPath)
        }
      } else {
        root.errorText = root.trf("error.addThemeImage", {
          detail: themeImageProc.failureText || ("exit " + code)
        })
        root.debugLog("error", root.errorText)
      }
      themeImageProc.addedPath = ""
      themeImageProc.failureText = ""
    }
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "elinchi-wallpaper-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.68)
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()

      Item {
        id: cardFrame
        anchors.centerIn: parent
        width: Math.min(Style.space(900), keyCatcher.width - Style.space(36))
        height: Math.min(Style.space(790), keyCatcher.height - Style.space(36))
        scale: Math.min(1, (keyCatcher.width - Style.space(24)) / Math.max(1, width),
          (keyCatcher.height - Style.space(24)) / Math.max(1, height))

        Rectangle {
          id: card
          anchors.fill: parent
          radius: Style.cornerRadius * 1.5
          color: Color.popups.background
          border.width: Math.max(1, Style.space(1))
          border.color: Color.popups.border
          clip: true
          MouseArea { anchors.fill: parent; onClicked: {} }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(22)
            spacing: Style.space(14)

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(3)
                Text {
                  text: "OBRII"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.6
                }
                Text {
                  text: root.activeTab === "wallpaper" ? root.tr("title.wallpaper") : root.tr("title.monitors")
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Text {
                  text: root.activeTab === "wallpaper"
                    ? root.tr("subtitle.wallpaper")
                    : root.tr("subtitle.monitors")
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.Wrap
                }
              }
              Item { Layout.fillWidth: true }
              ColumnLayout {
                visible: !!root.currentTheme
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(3)
                Text {
                  Layout.fillWidth: true
                  text: root.tr("theme.caption")
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.6
                  horizontalAlignment: Text.AlignRight
                }
                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignRight
                  text: root.currentTheme
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  Layout.maximumWidth: Style.space(260)
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: root.tr("theme.currentHint")
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  horizontalAlignment: Text.AlignRight
                }
              }
              Button { text: "×"; onClicked: root.dismiss(); implicitWidth: Style.space(38); implicitHeight: Style.space(38) }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)
              Button {
                text: root.tr("tab.wallpaper")
                selected: root.activeTab === "wallpaper"
                enabled: !root.displayDirty
                onClicked: root.activeTab = "wallpaper"
              }
              Button {
                text: root.tr("tab.monitors")
                selected: root.activeTab === "monitors"
                onClicked: {
                  root.activeTab = "monitors"
                  root.updateLayoutBounds()
                  if (!loadMonitorsProc.running) loadMonitorsProc.running = true
                }
              }
              Item { Layout.fillWidth: true }
            }

            RowLayout {
              Layout.fillWidth: true
              visible: root.activeTab === "wallpaper"
              spacing: Style.space(8)
              Repeater {
                model: root.monitors
                Button {
                  required property var modelData
                  text: modelData.name + (modelData.name === "DP-3" ? " · " + root.tr("monitor.primary") : "") + "  " + modelData.logicalWidth + "×" + modelData.logicalHeight + (modelData.logicalWidth >= modelData.logicalHeight ? " · " + root.tr("monitor.landscape") : " · " + root.tr("monitor.portrait"))
                  selected: root.selectedMonitor === modelData.name
                  onClicked: root.setMonitor(modelData.name)
                }
              }
              Item { Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Color.popups.border }

            RowLayout {
              visible: root.activeTab === "wallpaper"
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.space(22)

              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.25
                spacing: Style.space(8)

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    Layout.fillWidth: true
                    text: root.selectedWallpaper ? root.selectedWallpaper.split("/").pop() : root.tr("wallpaper.themeGlobal")
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideMiddle
                  }
                  Text {
                    text: root.selectedConfig.wallpaper ? root.tr("badge.own")
                      : (root.hasMonitorOverride ? root.tr("badge.globalMoved") : root.tr("badge.global"))
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Rectangle {
                  id: previewFrame
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.minimumHeight: Style.space(220)
                  color: "#11151a"
                  radius: Style.cornerRadius
                  border.width: 1
                  border.color: Color.popups.border
                  clip: true

                  Rectangle {
                    id: previewCanvas
                    width: height * root.selectedAspect
                    height: Math.min(parent.height - Style.space(16), parent.width / Math.max(0.35, root.selectedAspect))
                    anchors.centerIn: parent
                    color: "#20252c"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    clip: true

                    Image {
                      id: previewImage
                      source: root.imageUrl(root.selectedWallpaper)
                      asynchronous: true
                      cache: false
                      smooth: true
                      fillMode: root.currentMode === "tile" ? Image.Tile : Image.Stretch

                      // The preview is the monitor drawn at a fraction of its
                      // size, so offsets (stored in monitor logical pixels) are
                      // scaled by the same factor before WallpaperMath runs.
                      // previewCanvas keeps the monitor's aspect ratio, so this
                      // matches the real renderer exactly.
                      readonly property real offsetScaleX: previewCanvas.width / Math.max(1, root.selectedInfo.logicalWidth)
                      readonly property real offsetScaleY: previewCanvas.height / Math.max(1, root.selectedInfo.logicalHeight)

                      readonly property var geometry: WallpaperMath.layout({
                        mode: root.currentMode,
                        position: root.selectedConfig.position || "center",
                        imageW: previewImage.implicitWidth,
                        imageH: previewImage.implicitHeight,
                        screenW: previewCanvas.width,
                        screenH: previewCanvas.height,
                        offsetX: root.offsetX * offsetScaleX,
                        offsetY: root.offsetY * offsetScaleY
                      })

                      width: geometry.width
                      height: geometry.height
                      x: geometry.x
                      y: geometry.y
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: !root.selectedWallpaper
                      text: root.tr("preview.empty")
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                    }

                    MouseArea {
                      id: dragArea
                      anchors.fill: parent
                      enabled: !!root.selectedWallpaper && !root.busy
                      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                      property real previousX: 0
                      property real previousY: 0
                      onPressed: function(mouse) {
                        previousX = mouse.x; previousY = mouse.y
                        root.dragging = true
                      }
                      onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var dx = mouse.x - previousX
                        var dy = mouse.y - previousY
                        root.offsetX = Math.round(root.offsetX + dx / Math.max(0.0001, previewImage.offsetScaleX))
                        root.offsetY = Math.round(root.offsetY + dy / Math.max(0.0001, previewImage.offsetScaleY))
                        previousX = mouse.x
                        previousY = mouse.y
                      }
                      onReleased: {
                        root.dragging = false
                        root.saveOffsets(root.offsetX, root.offsetY)
                      }
                    }
                  }
                }
                Text {
                  Layout.fillWidth: true
                  text: root.tr("preview.hint")
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Style.space(300)
                spacing: Style.space(14)

                Dropdown {
                  Layout.fillWidth: true
                  label: root.tr("mode.label")
                  options: root.modeOptions
                  value: root.currentMode
                  enabled: !root.busy
                  onChanged: function(value) {
                    root.currentMode = value
                    root.runCommand(["omarchy-per-monitor-bg", "set-mode", root.selectedMonitor, value])
                  }
                }

                Dropdown {
                  Layout.fillWidth: true
                  label: root.tr("position.label")
                  options: root.positionOptions
                  value: root.currentPosition
                  enabled: !root.busy && (root.currentMode === "crop" || root.currentMode === "fit")
                  onChanged: function(value) { root.savePosition(value) }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Color.popups.border }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(3)
                  RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: root.tr("offset.x"); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                    Text { text: root.offsetX + " px"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                    Button {
                      text: "↺"
                      tooltipText: root.tr("offset.resetX")
                      fontSize: Style.font.bodySmall
                      horizontalPadding: Style.space(6)
                      verticalPadding: Style.space(2)
                      enabled: !root.busy && root.offsetX !== 0
                      onClicked: root.saveOffsetX(0)
                    }
                  }
                  PanelSlider {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    minimum: -Math.round((root.selectedInfo.logicalWidth || 1920) / 2)
                    maximum: Math.round((root.selectedInfo.logicalWidth || 1920) / 2)
                    step: 1
                    integer: true
                    value: root.offsetX
                    onMoved: function(v) { root.offsetX = Math.round(v) }
                    onReleased: function(v) { root.saveOffsetX(v) }
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(3)
                  RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: root.tr("offset.y"); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                    Text { text: root.offsetY + " px"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                    Button {
                      text: "↺"
                      tooltipText: root.tr("offset.resetY")
                      fontSize: Style.font.bodySmall
                      horizontalPadding: Style.space(6)
                      verticalPadding: Style.space(2)
                      enabled: !root.busy && root.offsetY !== 0
                      onClicked: root.saveOffsetY(0)
                    }
                  }
                  PanelSlider {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    minimum: -Math.round((root.selectedInfo.logicalHeight || 1080) / 2)
                    maximum: Math.round((root.selectedInfo.logicalHeight || 1080) / 2)
                    step: 1
                    integer: true
                    value: root.offsetY
                    onMoved: function(v) { root.offsetY = Math.round(v) }
                    onReleased: function(v) { root.saveOffsetY(v) }
                  }
                }

                Item { Layout.fillHeight: true }

                Text {
                  Layout.fillWidth: true
                  text: root.errorText || root.configError || root.statusMessage || (root.busy ? root.tr("status.busy")
                    : (root.selectedConfig.wallpaper ? root.tr("status.ownWallpaper")
                      : (root.hasMonitorOverride ? root.tr("status.globalMoved")
                        : root.tr("status.global"))))
                  color: (root.errorText || root.configError) ? Color.urgent
                    : (root.statusMessage ? Color.accent : Color.muted)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
              }
            }

            RowLayout {
              visible: root.activeTab === "monitors"
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: Style.space(18)

              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.2
                spacing: Style.space(8)
                Text {
                  text: root.tr("layout.title")
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  Layout.fillWidth: true
                  text: root.tr("layout.hint")
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
                Rectangle {
                  id: layoutFrame
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.minimumHeight: Style.space(240)
                  color: Qt.rgba(0, 0, 0, 0.20)
                  radius: Style.cornerRadius
                  border.width: 1
                  border.color: Color.popups.border

                  Item {
                    id: layoutCanvas
                    anchors.fill: parent
                    anchors.margins: Style.space(8)

                    Repeater {
                      model: root.monitors
                      delegate: Item {
                        required property var modelData
                        x: root.monitorTileX(modelData)
                        y: root.monitorTileY(modelData)
                        width: Math.max(Style.space(58), root.monitorTileWidth(modelData) * root.layoutScale)
                        height: Math.max(Style.space(48), root.monitorTileHeight(modelData) * root.layoutScale)

                        Rectangle {
                          anchors.fill: parent
                          radius: Style.cornerRadius
                          color: root.selectedMonitor === modelData.name
                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                            : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.10)
                          border.width: root.selectedMonitor === modelData.name ? 2 : 1
                          border.color: root.selectedMonitor === modelData.name ? Color.accent : Color.popups.border
                          Column {
                            anchors.centerIn: parent
                            width: parent.width - Style.space(8)
                            spacing: Style.space(2)
                            Text {
                              anchors.horizontalCenter: parent.horizontalCenter
                              text: modelData.name
                              color: Color.foreground
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              font.bold: true
                            }
                            Text {
                              anchors.horizontalCenter: parent.horizontalCenter
                              text: modelData.width + "×" + modelData.height
                              color: Color.muted
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                            }
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                          property real originX: 0
                          property real originY: 0
                          property real pointerX: 0
                          property real pointerY: 0
                          property real dragScale: 0.06
                          onPressed: function(mouse) {
                            if (modelData.name !== root.selectedMonitor && !root.setMonitor(modelData.name)) {
                              mouse.accepted = false
                              return
                            }
                            originX = root.displayX
                            originY = root.displayY
                            dragScale = root.layoutScale
                            var point = mapToItem(layoutCanvas, mouse.x, mouse.y)
                            pointerX = point.x
                            pointerY = point.y
                          }
                          onPositionChanged: function(mouse) {
                            if (!pressed) return
                            var point = mapToItem(layoutCanvas, mouse.x, mouse.y)
                            root.displayX = Math.round(originX + (point.x - pointerX) / Math.max(0.001, dragScale))
                            root.displayY = Math.round(originY + (point.y - pointerY) / Math.max(0.001, dragScale))
                            root.displayDirty = true
                            root.updateLayoutBounds()
                          }
                        }
                      }
                    }
                  }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    Layout.fillWidth: true
                    text: root.selectedMonitor + " · " + root.displayX + "×" + root.displayY
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    text: root.monitors.length + " " + (root.monitors.length === 1 ? root.tr("monitor.count.one") : root.tr("monitor.count.many"))
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumWidth: Style.space(340)
                spacing: Style.space(10)

                Dropdown {
                  Layout.fillWidth: true
                  options: root.monitorOptions
                  value: root.selectedMonitor
                  showLabel: false
                  onChanged: function(value) { root.setMonitor(value) }
                }
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(8)
                  ColumnLayout {
                    Layout.fillWidth: true
                    Dropdown {
                      Layout.fillWidth: true
                      label: root.tr("display.resolution")
                      options: root.resolutionOptions(root.selectedMonitor)
                      value: root.selectedResolution
                      onChanged: function(value) { root.selectResolution(value) }
                    }
                  }
                  ColumnLayout {
                    Layout.preferredWidth: Style.space(120)
                    Dropdown {
                      Layout.fillWidth: true
                      label: root.tr("display.refresh")
                      options: root.refreshOptions(root.selectedMonitor, root.selectedResolution)
                      value: root.selectedRefresh
                      onChanged: function(value) { root.selectRefresh(value) }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  Text { Layout.fillWidth: true; text: root.tr("display.scale"); color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                  Text { text: Math.round(root.displayScale * 100) + "%"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
                  Button {
                    text: root.tr("display.resetScale")
                    bordered: true
                    fontSize: Style.font.bodySmall
                    enabled: !root.displayBusy && Math.abs(root.displayScale - root.nearestValidScale(root.defaultDisplayScale(root.selectedMonitor))) > 0.001
                    onClicked: root.resetDisplayScale()
                  }
                }
                PanelSlider {
                  Layout.fillWidth: true
                  minimum: 0.5
                  maximum: 2.0
                  step: 0.05
                  value: root.displayScale
                  onMoved: function(v) {
                    root.displayScale = root.nearestValidScale(v)
                    root.displayDirty = true
                    root.updateLayoutBounds()
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  Dropdown {
                    Layout.fillWidth: true
                    label: root.tr("display.orientation")
                    options: root.orientationOptions
                    value: String(root.displayTransform)
                    onChanged: function(value) {
                      root.displayTransform = Number(value)
                      root.displayDirty = true
                      root.updateLayoutBounds()
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(12)
                  NumberField {
                    label: root.tr("display.x")
                    from: -10000
                    to: 10000
                    value: root.displayX
                    onModified: function(value) {
                      root.displayX = value
                      root.displayDirty = true
                      root.updateLayoutBounds()
                    }
                  }
                  NumberField {
                    label: root.tr("display.y")
                    from: -10000
                    to: 10000
                    value: root.displayY
                    onModified: function(value) {
                      root.displayY = value
                      root.displayDirty = true
                      root.updateLayoutBounds()
                    }
                  }
                  Item { Layout.fillWidth: true }
                }

                Text {
                  Layout.fillWidth: true
                  visible: !!root.displayError
                  text: root.displayError
                  color: Color.urgent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
                Text {
                  Layout.fillWidth: true
                  visible: !root.displayError && !!root.displayWarning
                  text: root.displayWarning
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
                Item { Layout.fillHeight: true }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)
              visible: root.activeTab === "wallpaper"
              Button {
                text: root.busy ? root.tr("button.wait") : root.tr("button.chooseImage")
                enabled: !root.busy && !!root.selectedMonitor
                onClicked: {
                  root.busy = true
                  chooseMonitorProc.command = ["omarchy-per-monitor-bg", "select", root.selectedMonitor]
                  chooseMonitorProc.running = true
                }
              }
              /*
               * Глобальна шпалера тимчасово прихована: нею керує Omarchy, і
               * вона не зберігається per-theme. Повернути — розкоментувати.
               *
               * Button {
               *   text: "Змінити загальні…"
               *   enabled: !root.busy
               *   onClicked: chooseGlobalProc.running = true
               * }
               */
              Button {
                text: root.tr("button.changeTheme")
                enabled: !root.busy
                onClicked: root.changeTheme()
              }
              Button {
                text: root.tr("button.addThemeImage")
                enabled: !root.busy
                onClicked: {
                  root.statusMessage = ""
                  root.errorText = ""
                  root.busy = true
                  themeImageProc.running = true
                }
              }
              Button {
                text: root.tr("button.resetMonitor")
                enabled: !root.busy && root.hasMonitorOverride
                onClicked: root.runCommand(["omarchy-per-monitor-bg", "clear", root.selectedMonitor])
              }
              Item { Layout.fillWidth: true }
              Button { text: root.tr("button.done"); onClicked: root.dismiss() }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)
              visible: root.activeTab === "monitors"
              Button { text: root.tr("button.refreshList"); enabled: !root.displayBusy && !root.displayDirty; onClicked: loadMonitorsProc.running = true }
              Text {
                Layout.fillWidth: true
                text: root.displayBusy ? root.tr("status.displayBusy") : (root.displayDirty ? root.tr("status.displayDirty") : root.tr("status.displayClean"))
                color: root.displayDirty ? Color.accent : Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
              }
              Button {
                text: root.tr("button.apply")
                enabled: !root.displayBusy && root.displayDirty
                onClicked: root.applyDisplaySettings()
              }
              Button { text: root.tr("button.done"); onClicked: root.dismiss() }
            }
          }
        }
      }
    }
  }
}
