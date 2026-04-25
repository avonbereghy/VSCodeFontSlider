import Foundation
import CryptoKit
import Combine

final class SettingsManager: ObservableObject {

    // MARK: - Published State

    @Published var zoomLevel: Double = FontSettings.vsCodeDefaults.zoomLevel
    @Published var editorFontSize: Int = FontSettings.vsCodeDefaults.editorFontSize
    @Published var terminalFontSize: Int = FontSettings.vsCodeDefaults.terminalFontSize
    @Published var errorMessage: String?

    // MARK: - Private

    private let settingsURL: URL
    private let directoryURL: URL
    private var lastWrittenHash: String = ""
    private var debounceTask: Task<Void, Never>?
    private var watcherDebounceTask: Task<Void, Never>?
    private var directoryWatcherSource: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1

    /// Original values — persisted to UserDefaults so "Default" works across app restarts
    private var originalSettings: FontSettings?

    // UserDefaults keys for persisting original settings
    private static let udKeyOriginalZoom = "FontDial.original.zoomLevel"
    private static let udKeyOriginalEditor = "FontDial.original.editorFontSize"
    private static let udKeyOriginalTerminal = "FontDial.original.terminalFontSize"
    private static let udKeyHasOriginal = "FontDial.original.saved"

    // Keys we manage
    private static let keyZoom = "window.zoomLevel"
    private static let keyEditor = "editor.fontSize"
    private static let keyTerminal = "terminal.integrated.fontSize"

    // MARK: - Init

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.settingsURL = home
            .appendingPathComponent("Library/Application Support/Code/User/settings.json")
        self.directoryURL = settingsURL.deletingLastPathComponent()
    }

    deinit {
        stopWatching()
    }

    // MARK: - Load

    func load() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            // Create default settings.json if it doesn't exist
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                try Data("{\n}\n".utf8).write(to: settingsURL, options: .atomic)
            } catch {
                errorMessage = "VS Code settings not found at \(settingsURL.path)"
                return
            }
            errorMessage = nil
            startWatching()
            return
        }

        do {
            try readAndApply()
            startWatching()
        } catch {
            errorMessage = "Could not read VS Code settings: \(error.localizedDescription)"
        }
    }

    private func readAndApply() throws {
        let rawText = try String(contentsOf: settingsURL, encoding: .utf8)
        let cleaned = JSONCScanner.strip(rawText)
        guard let data = cleaned.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            errorMessage = "Could not parse VS Code settings"
            return
        }

        zoomLevel = json[Self.keyZoom] as? Double ?? FontSettings.vsCodeDefaults.zoomLevel
        editorFontSize = (json[Self.keyEditor] as? NSNumber)?.intValue ?? FontSettings.vsCodeDefaults.editorFontSize
        terminalFontSize = (json[Self.keyTerminal] as? NSNumber)?.intValue ?? FontSettings.vsCodeDefaults.terminalFontSize
        errorMessage = nil

        // Load persisted original or capture on first-ever load
        if originalSettings == nil {
            let ud = UserDefaults.standard
            if ud.bool(forKey: Self.udKeyHasOriginal) {
                originalSettings = FontSettings(
                    zoomLevel: ud.double(forKey: Self.udKeyOriginalZoom),
                    editorFontSize: ud.integer(forKey: Self.udKeyOriginalEditor),
                    terminalFontSize: ud.integer(forKey: Self.udKeyOriginalTerminal)
                )
            } else {
                let orig = FontSettings(
                    zoomLevel: zoomLevel,
                    editorFontSize: editorFontSize,
                    terminalFontSize: terminalFontSize
                )
                originalSettings = orig
                ud.set(true, forKey: Self.udKeyHasOriginal)
                ud.set(orig.zoomLevel, forKey: Self.udKeyOriginalZoom)
                ud.set(orig.editorFontSize, forKey: Self.udKeyOriginalEditor)
                ud.set(orig.terminalFontSize, forKey: Self.udKeyOriginalTerminal)
            }
        }
    }

    // MARK: - Save

    func save() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self.writeSettings()
        }
    }

    private func writeSettings() {
        do {
            var rawText: String
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                rawText = try String(contentsOf: settingsURL, encoding: .utf8)
            } else {
                rawText = "{\n}\n"
            }

            // Update each key via targeted replacement
            rawText = updateKey(Self.keyZoom, value: formatZoom(zoomLevel), in: rawText)
            rawText = updateKey(Self.keyEditor, value: "\(editorFontSize)", in: rawText)
            rawText = updateKey(Self.keyTerminal, value: "\(terminalFontSize)", in: rawText)

            // Atomic write
            let data = Data(rawText.utf8)
            try data.write(to: settingsURL, options: .atomic)

            // Store hash for self-trigger guard
            lastWrittenHash = sha256(data)
            errorMessage = nil
        } catch {
            errorMessage = "Could not save settings: \(error.localizedDescription)"
        }
    }

    // MARK: - Targeted Key Replacement

    private func updateKey(_ key: String, value: String, in text: String) -> String {
        if let range = JSONCScanner.findValueRange(forKey: key, in: text) {
            var modified = text
            modified.replaceSubrange(range, with: value)
            return modified
        } else {
            return insertKey(key, value: value, in: text)
        }
    }

    private func insertKey(_ key: String, value: String, in text: String) -> String {
        guard let insertIdx = JSONCScanner.insertionPoint(in: text) else {
            return text
        }

        let beforeClose = text[text.startIndex..<insertIdx]
        let lastNonWhitespace = beforeClose.last { !$0.isWhitespace && !$0.isNewline }
        let newEntry = "    \"\(key)\": \(value)"

        var modified = text
        if lastNonWhitespace == "{" {
            modified.insert(contentsOf: "\n\(newEntry)\n", at: insertIdx)
        } else if lastNonWhitespace == "," {
            modified.insert(contentsOf: "\n\(newEntry)\n", at: insertIdx)
        } else {
            // Add comma after the last existing property
            modified.insert(contentsOf: ",\n\(newEntry)\n", at: insertIdx)
        }

        return modified
    }

    // MARK: - File Watching

    private func startWatching() {
        stopWatching()

        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.debouncedHandleFileChange()
        }

        source.setCancelHandler { [fd] in
            close(fd)
        }

        source.resume()
        directoryWatcherSource = source
    }

    private func stopWatching() {
        directoryWatcherSource?.cancel()
        directoryWatcherSource = nil
        directoryFD = -1
    }

    private func debouncedHandleFileChange() {
        watcherDebounceTask?.cancel()
        watcherDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.handleFileChange()
        }
    }

    private func handleFileChange() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            errorMessage = "VS Code settings not found at \(settingsURL.path)"
            return
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            let hash = sha256(data)

            // Self-trigger guard: skip if this is our own write
            if hash == lastWrittenHash { return }

            guard let rawText = String(data: data, encoding: .utf8) else { return }
            let cleaned = JSONCScanner.strip(rawText)
            guard let cleanData = cleaned.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: cleanData) as? [String: Any] else {
                errorMessage = "Could not parse VS Code settings"
                return
            }

            zoomLevel = json[Self.keyZoom] as? Double ?? FontSettings.vsCodeDefaults.zoomLevel
            editorFontSize = (json[Self.keyEditor] as? NSNumber)?.intValue ?? FontSettings.vsCodeDefaults.editorFontSize
            terminalFontSize = (json[Self.keyTerminal] as? NSNumber)?.intValue ?? FontSettings.vsCodeDefaults.terminalFontSize
            errorMessage = nil
        } catch {
            // File might be mid-write, ignore transient errors
        }
    }

    // MARK: - Helpers

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func formatZoom(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value).replacingOccurrences(of: "0$", with: "", options: .regularExpression)
    }

    // MARK: - Apply Preset

    func apply(_ preset: FontSettings) {
        zoomLevel = preset.zoomLevel
        editorFontSize = preset.editorFontSize
        terminalFontSize = preset.terminalFontSize
        save()
    }

    /// Restore the settings that were active when FontDial first launched
    func restoreOriginal() {
        guard let original = originalSettings else { return }
        apply(original)
    }
}
