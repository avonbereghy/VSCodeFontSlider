import Foundation

struct FontSettings {
    var zoomLevel: Double
    var editorFontSize: Int
    var terminalFontSize: Int
}

extension FontSettings {
    static let compact  = FontSettings(zoomLevel: -0.5, editorFontSize: 12, terminalFontSize: 11)
    static let standard = FontSettings(zoomLevel: 0.0,  editorFontSize: 14, terminalFontSize: 14)
    static let relaxed  = FontSettings(zoomLevel: 0.5,  editorFontSize: 16, terminalFontSize: 15)

    /// VS Code's actual defaults when a key is absent from settings.json
    static let vsCodeDefaults = FontSettings(zoomLevel: 0.0, editorFontSize: 14, terminalFontSize: 14)
}
