import Foundation

struct FontSettings: Equatable, Codable {
    var zoomLevel: Double
    var editorFontSize: Int
    var terminalFontSize: Int
    var chatFontSize: Int
    var chatEditorFontSize: Int
}

extension FontSettings {
    static let compact  = FontSettings(zoomLevel: -0.5, editorFontSize: 12, terminalFontSize: 11, chatFontSize: 11, chatEditorFontSize: 12)
    static let relaxed  = FontSettings(zoomLevel: 0.5,  editorFontSize: 16, terminalFontSize: 15, chatFontSize: 15, chatEditorFontSize: 16)

    /// VS Code's actual defaults when a key is absent from settings.json
    static let vsCodeDefaults = FontSettings(zoomLevel: 0.0, editorFontSize: 14, terminalFontSize: 14, chatFontSize: 13, chatEditorFontSize: 14)
}
