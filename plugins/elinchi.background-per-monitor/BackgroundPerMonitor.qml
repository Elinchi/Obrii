import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui

import "WallpaperMath.js" as WallpaperMath

// Per-monitor desktop background renderer for Omarchy.
//
// This is a drop-in replacement for the stock `omarchy.background` service
// that additionally understands a per-monitor configuration file. The global
// wallpaper is ALWAYS the Omarchy theme background symlink
// (`~/.local/state/omarchy/current/background`), so switching themes updates
// every monitor that does not define its own wallpaper, and theme-derived
// per-monitor wallpapers are kept in sync by `omarchy-per-monitor-bg
// sync-theme` during the theme transition IPC.
//
// The reveal transition mirrors the stock plugin: the animating frame uses the
// snapshot files Omarchy drops into `~/.cache/omarchy/background-transitions`,
// while the committed path is the real theme file. Because the theme directory
// is swapped *in place* (same path, new content), the base image is explicitly
// reloaded when a theme transition leaves the path unchanged.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string configFile: home + "/.config/omarchy/backgrounds-per-monitor.json"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  // Global (theme) wallpaper — resolved through the Omarchy symlink.
  property string globalBackground: ""
  // Per-monitor overrides: { "<monitor>": { wallpaper, mode, position, offset_x, offset_y } }
  property var monitorConfig: ({})
  property int backgroundVersion: 0

  // Theme payloads are decoded and applied together with the reveal so the
  // palette flips at the same moment the wallpaper does.
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property int pendingThemeVersion: -1

  // Theme transition context.
  property bool themeInProgress: false
  property string transitionOld: ""
  property string transitionNew: ""

  property var panels: []

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  // ---- config ------------------------------------------------------------

  function applyConfig() {
    var raw = ""
    try { raw = configView.text() } catch (e) { raw = "" }
    var parsed = {}
    try { parsed = JSON.parse(raw || "{}") || {} } catch (e) { parsed = {} }
    var monitors = (parsed.monitors && typeof parsed.monitors === "object") ? parsed.monitors : ({})
    root.monitorConfig = monitors
    root.backgroundVersion += 1
    for (var i = 0; i < root.panels.length; i++) root.panels[i].refresh(true)
  }

  // ---- global (theme) background ----------------------------------------

  function applyGlobal(path, animate) {
    path = String(path || "").trim()
    if (!path || path === root.globalBackground) return
    root.globalBackground = path
    root.backgroundVersion += 1
    for (var i = 0; i < root.panels.length; i++) root.panels[i].refresh(animate === true)
  }

  function refreshGlobal() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  // ---- theme palette -----------------------------------------------------

  function setPendingTheme(colorsB64, shellB64) {
    root.pendingColorsRaw = Util.decodeBase64(colorsB64 || "")
    root.pendingShellRaw = Util.decodeBase64(shellB64 || "")
    root.pendingThemeVersion = root.backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    if (root.pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Color.loadColors(root.pendingColorsRaw)
    Color.loadShell(root.pendingShellRaw)
    Style.scheduleRefresh()
    root.pendingThemeVersion = -1
    root.pendingColorsRaw = ""
    root.pendingShellRaw = ""
  }

  // ---- theme transition --------------------------------------------------

  function transitionTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    setPendingTheme(colorsB64, shellB64)
    root.transitionOld = String(fromPath || "").trim()
    root.transitionNew = String(path || "").trim()
    root.themeInProgress = true

    var finalP = String(finalPath || "").trim()
    if (!finalP) {
      // No real background (theme ships none): just refresh colors.
      root.themeInProgress = false
      applyPendingTheme()
      return
    }
    themeSyncProc.pendingFinal = finalP
    themeSyncProc.command = ["omarchy-per-monitor-bg", "sync-theme", finalP]
    themeSyncProc.running = true
  }

  function finishThemeTransition(finalP) {
    if (finalP && finalP !== root.globalBackground) {
      root.globalBackground = finalP
      root.backgroundVersion += 1
      for (var i = 0; i < root.panels.length; i++) root.panels[i].refresh(true)
    }
    root.themeInProgress = false
    root.transitionOld = ""
    root.transitionNew = ""
  }

  // ---- external pickers --------------------------------------------------

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  // ---- processes ---------------------------------------------------------

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.applyGlobal(String(text || "").trim(), true)
    }
  }

  Timer {
    id: globalPoll
    interval: 4000
    repeat: true
    running: true
    onTriggered: root.refreshGlobal()
  }

  FileView {
    id: configView
    path: root.configFile
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig()
    onFileChanged: reload()
    onLoadFailed: root.applyConfig()
  }

  Process {
    id: themeSyncProc
    property string pendingFinal: ""
    command: ["true"]
    onExited: function (code) {
      if (code !== 0)
        console.warn("Could not sync per-monitor wallpapers for the new theme")
      root.finishThemeTransition(themeSyncProc.pendingFinal)
    }
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshGlobal()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshGlobal()
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 500
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  IpcHandler {
    target: "background"

    function refresh(): void { root.refreshGlobal() }
    function set(path: string): void { root.applyGlobal(path, true) }
    function setInstant(path: string): void { root.applyGlobal(path, false) }
    function transition(fromPath: string, path: string): void { root.applyGlobal(path, true) }
    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
  }

  Component.onCompleted: {
    refreshGlobal()
    configView.reload()
  }

  // ---- renderers ---------------------------------------------------------

  Variants {
    model: Quickshell.screens

    MonitorBackground {
      required property var modelData
      screen: modelData
    }
  }

  // A single wallpaper image with crop/fit/stretch/tile + position + offsets.
  // The geometry is computed by WallpaperMath.layout so the editor preview and
  // the real monitor can never drift apart.
  component BgImage: Image {
    id: bgImage
    property string mode: "crop"
    property string pos: "center"
    property real offX: 0
    property real offY: 0
    property real screenW: 1
    property real screenH: 1

    asynchronous: true
    smooth: true
    mipmap: true
    fillMode: mode === "tile" ? Image.Tile : Image.Stretch

    readonly property var geometry: WallpaperMath.layout({
      mode: bgImage.mode,
      position: bgImage.pos,
      imageW: bgImage.implicitWidth,
      imageH: bgImage.implicitHeight,
      screenW: bgImage.screenW,
      screenH: bgImage.screenH,
      offsetX: bgImage.offX,
      offsetY: bgImage.offY
    })

    width: geometry.width
    height: geometry.height
    x: geometry.x
    y: geometry.y
  }

  component MonitorBackground: PanelWindow {
    id: panel

    visible: !remapGuard.remapping
    anchors { top: true; bottom: true; left: true; right: true }
    ScreenMoveRemap { id: remapGuard; window: panel }
    color: "transparent"
    updatesEnabled: true

    readonly property string monitorName: modelData ? modelData.name : ""
    property var mc: ({})
    property string displayedPath: ""
    property string incomingPath: ""
    property string oldPath: ""
    property string incomingCommit: ""
    property bool maskReady: false
    property real revealProgress: 1

    function effectiveWallpaper() {
      var c = root.monitorConfig[panel.monitorName] || ({} )
      var wp = c.wallpaper
      if (wp && wp !== "null") return wp
      return root.globalBackground
    }

    function applySources() {
      var b = panel.displayedPath ? root.imageUrl(panel.displayedPath) : ""
      if (baseImage.source != b) baseImage.source = b
      incomingImage.source = panel.incomingPath ? root.imageUrl(panel.incomingPath) : ""
      oldImage.source = panel.oldPath ? root.imageUrl(panel.oldPath) : ""
    }

    function reloadBase() {
      baseImage.source = ""
      Qt.callLater(function () {
        baseImage.source = panel.displayedPath ? root.imageUrl(panel.displayedPath) : ""
      })
    }

    function refresh(animate) {
      panel.mc = root.monitorConfig[panel.monitorName] || ({} )
      var target = panel.effectiveWallpaper()
      if (!target) {
        panel.displayedPath = ""
        panel.incomingPath = ""
        panel.oldPath = ""
        panel.incomingCommit = ""
        panel.revealProgress = 1
        panel.maskReady = false
        panel.applySources()
        return
      }
      if (target === panel.displayedPath) {
        // Same path but the theme swapped the directory in place: reload.
        if (root.themeInProgress) panel.reloadBase()
        return
      }
      if (animate && panel.displayedPath !== "") {
        panel.oldPath = (root.themeInProgress && root.transitionOld) ? root.transitionOld : panel.displayedPath
        panel.incomingPath = (root.themeInProgress && root.transitionNew) ? root.transitionNew : target
        panel.incomingCommit = target
        panel.maskReady = false
        panel.revealProgress = 0
        panel.applySources()
        revealFallback.restart()
      } else {
        panel.displayedPath = target
        panel.incomingPath = ""
        panel.oldPath = ""
        panel.incomingCommit = ""
        panel.revealProgress = 1
        panel.maskReady = false
        panel.applySources()
      }
    }

    function maybeStartReveal() {
      if (!panel.incomingPath || panel.revealProgress !== 0 || panel.maskReady) return
      if (incomingImage.status !== Image.Ready) return
      Qt.callLater(function () {
        if (!panel.incomingPath || panel.revealProgress !== 0 || panel.maskReady) return
        if (incomingImage.status !== Image.Ready) return
        panel.maskReady = true
        root.applyPendingTheme()
        revealAnimation.restart()
      })
    }

    function finishReveal() {
      if (panel.incomingPath !== "") {
        panel.displayedPath = panel.incomingCommit || panel.incomingPath
        panel.applySources()
      }
      panel.incomingPath = ""
      panel.oldPath = ""
      panel.incomingCommit = ""
      panel.revealProgress = 1
      panel.maskReady = false
      revealFallback.stop()
    }

    WlrLayershell.namespace: "elinchi-background-per-monitor"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Component.onCompleted: {
      root.panels.push(panel)
      panel.refresh(false)
    }

    NumberAnimation {
      id: revealAnimation
      target: panel
      property: "revealProgress"
      from: 0
      to: 1
      duration: 420
      easing.type: Easing.InOutCubic
      onFinished: panel.finishReveal()
    }

    Timer {
      id: revealFallback
      interval: 2000
      repeat: false
      onTriggered: panel.finishReveal()
    }

    Item {
      id: baseClip
      anchors.fill: parent
      clip: true

      BgImage {
        id: baseImage
        mode: panel.mc.mode || "crop"
        pos: panel.mc.position || "center"
        offX: panel.mc.offset_x || 0
        offY: panel.mc.offset_y || 0
        screenW: panel.width
        screenH: panel.height
        cache: false
      }
    }

    Item {
      id: incomingClip
      anchors.fill: parent
      clip: true
      visible: panel.incomingPath !== "" && incomingImage.status === Image.Ready
        && (panel.revealProgress >= 1 || panel.maskReady)
      layer.enabled: panel.incomingPath !== "" && panel.revealProgress < 1
      layer.smooth: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: revealMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.02
      }

      BgImage {
        id: incomingImage
        mode: panel.mc.mode || "crop"
        pos: panel.mc.position || "center"
        offX: panel.mc.offset_x || 0
        offY: panel.mc.offset_y || 0
        screenW: panel.width
        screenH: panel.height
        cache: false
        onStatusChanged: panel.maybeStartReveal()
      }
    }

    Item {
      id: oldClip
      anchors.fill: parent
      clip: true
      visible: panel.oldPath !== "" && panel.revealProgress < 1

      BgImage {
        id: oldImage
        mode: panel.mc.mode || "crop"
        pos: panel.mc.position || "center"
        offX: panel.mc.offset_x || 0
        offY: panel.mc.offset_y || 0
        screenW: panel.width
        screenH: panel.height
        cache: false
      }
    }

    Item {
      id: revealMask
      anchors.fill: parent
      visible: false
      layer.enabled: true

      readonly property real slant: -0.18
      readonly property real centerTop: width / 2 - slant * height / 2
      readonly property real centerBottom: width / 2 + slant * height / 2
      readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
      readonly property real spread: reach * panel.revealProgress

      Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: "white"
          strokeColor: "transparent"
          startX: revealMask.centerTop - revealMask.spread; startY: 0
          PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
          PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
          PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
          PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onDoubleClicked: function (mouse) {
        if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
        else root.openSelector()
        mouse.accepted = true
      }
    }
  }
}
