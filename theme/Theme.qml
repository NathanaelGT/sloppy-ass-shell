pragma Singleton
import Quickshell
import QtQuick

Singleton {
  id: theme

  readonly property real scale: 1.25

  readonly property int barThickness: 56
  readonly property int barRadius: Math.round(16 * scale)
  readonly property int barMargin: 320
  readonly property int menuRightInset: 40
  readonly property int capsuleThickness: Math.round(barThickness * 0.76)
  readonly property int capsuleRadius: Math.round(capsuleThickness / 2)
  readonly property int gap: Math.round(8 * scale)
  readonly property int cardRadius: Math.round(16 * scale)
  readonly property int dashboardWidth: Math.round(400 * scale)
  readonly property int panelWidth: Math.round(380 * scale)
  readonly property int rowRadius: Math.round(10 * scale)
  readonly property int shadowPad: Math.round(14 * scale)
  readonly property int bannerMaxExpand: 360
  readonly property int bannerRowHeight: Math.round(34 * scale)
  readonly property int bannerIconSize: Math.round(28 * scale)
  readonly property real shadowBlur: 0.45
  readonly property real shadowOpacity: 0.5
  readonly property int shadowVerticalOffset: Math.round(2 * scale)
  readonly property real scrollMultiplier: 2.0
  readonly property int scrollGlideIdleMs: 60
  readonly property int scrollGlideDurationMs: 400
  readonly property int scrollGlideTauMs: 140
  readonly property real scrollGlideMaxFrac: 0.5
  readonly property int scrollVelocityWindowMs: 200
  readonly property real scrollVelocityBlend: 0.5
  readonly property real scrollGlideMinVelocity: 0.9
  readonly property int scrollOvershootMs: 250
  readonly property int scrollOvershootCap: Math.round(40 * scale)
  readonly property real scrollOvershootVelMs: 25
  readonly property int scrollThumbGap: Math.max(2, Math.round(3 * scale))
  readonly property int scrollThumbWidth: Math.max(3, Math.round(3 * scale))
  readonly property int scrollThumbHoverWidth: scrollThumbWidth + 1
  readonly property int scrollThumbStrip: scrollThumbGap * 2 + scrollThumbWidth

  readonly property int chipHeight: Math.round(22 * scale)
  readonly property int chipRadius: Math.round(6 * scale)
  readonly property int chipPadX: Math.round(7 * scale)
  readonly property int chipGap: Math.round(4 * scale)
  readonly property int chipRowGap: Math.round(6 * scale)
  readonly property int dropdownWidth: Math.round(190 * scale)
  readonly property int dropdownRowHeight: Math.round(24 * scale)

  readonly property int fontSize: Math.round(12 * scale)
  readonly property int fontSizeSmall: Math.round(10 * scale)
  readonly property int fontSizeLarge: Math.round(15 * scale)
  readonly property int iconSize: Math.round(15 * scale)
  readonly property int iconSizeLarge: Math.round(19 * scale)

  readonly property string fontFamily: "Noto Sans"
  readonly property var locale: Qt.locale("id_ID")

  FontLoader {
    id: tabler
    source: "../assets/tabler.ttf"
  }
  readonly property string iconFamily: tabler.name

  readonly property color base: "#1e1e2e"
  readonly property color mantle: "#181825"
  readonly property color crust: "#11111b"
  readonly property color surface: "#313244"
  readonly property color surfaceHigh: "#45475a"
  readonly property color surfaceHigher: "#585b70"
  readonly property color qrSurface: "#fafafa"
  readonly property color qrHover: "#ccd0da"
  readonly property color overlay: "#6c7086"
  readonly property color text: "#cdd6f4"
  readonly property color subtext: "#a6adc8"
  readonly property color primary: "#89b4fa"
  readonly property color onAccent: "#11111b"
  readonly property color green: "#a6e3a1"
  readonly property color yellow: "#f9e2af"
  readonly property color red: "#f38ba8"
  readonly property color mauve: "#cba6f7"
  readonly property color teal: "#94e2d5"

  readonly property color capsuleFill: surface
  readonly property color capsuleHover: surfaceHigh
  readonly property color capsuleBorder: surfaceHigher
  readonly property color dropdownValueFill: "#4b4d61"
  readonly property color shadowColor: "#000000"
  readonly property color trackFill: surfaceHigh
  readonly property color knobFill: text
}
