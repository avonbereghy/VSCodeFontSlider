import Foundation

/// A named snapshot of the five values FontDial manages.
struct Preset: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var settings: FontSettings
    var isBuiltIn: Bool
}

extension Preset {
    /// The presets that ship with the app. Each can be overridden with your own
    /// values and reset back to the factory values here.
    enum BuiltIn: String, CaseIterable {
        case compact
        case standard
        case relaxed

        var displayName: String {
            switch self {
            case .compact: return "Compact"
            case .standard: return "Default"
            case .relaxed: return "Relaxed"
            }
        }

        /// Resetting a built-in preset restores these. "Default" always resets to
        /// VS Code's own defaults, not to whatever was in settings.json first.
        var factorySettings: FontSettings {
            switch self {
            case .compact: return .compact
            case .standard: return .vsCodeDefaults
            case .relaxed: return .relaxed
            }
        }
    }
}
