import CoreGraphics

enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let columnGutter: CGFloat = 18
}

enum Radius {
    static let chip: CGFloat = 8
    static let control: CGFloat = 10
    static let tile: CGFloat = 14  // control bar tiles, floating timer, popovers, swatches (canvas)
    static let card: CGFloat = 18
    static let sheet: CGFloat = 20
    static let hero: CGFloat = 22
    static let column: CGFloat = 26
    static let stage: CGFloat = 28  // Today stage (DESIGN_SYSTEM §4.2)
}

enum Layout {
    static let homeDefault = CGSize(width: 1200, height: 800)
    static let homeMin = CGSize(width: 900, height: 600)
    static let sidebarIdeal: CGFloat = 248
    static let sidebarMin: CGFloat = 200
    static let sidebarMax: CGFloat = 300
    static let inspectorIdeal: CGFloat = 380
    static let inspectorMin: CGFloat = 320
    static let inspectorMax: CGFloat = 460
    static let settingsWindow = CGSize(width: 760, height: 560)
    static let focusPanelWidth: CGFloat = 340
    static let floatingTimerHeight: CGFloat = 40
    static let floatingTimerMinWidth: CGFloat = 220
    static let floatingTimerMaxWidth: CGFloat = 460
    static let boardColumnMin: CGFloat = 260
    static let columnWeights: [CGFloat] = [1, 1.06, 1.52]  // Backlog, This week, Today
    static let reportsMaxWidth: CGFloat = 1080
    static let sheetConfirmWidth: CGFloat = 400
    static let sheetFormWidth: CGFloat = 480
    static let commandPaletteWidth: CGFloat = 560
}
