import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @Bindable var settingsManager: SettingsManager

    @State private var editorDouble: Double = 14
    @State private var terminalDouble: Double = 14
    @AppStorage("FontDial.showInDock") private var showInDock = false
    @AppStorage("FontDial.startAtLogin") private var startAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("FontDial")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 8)

            // Error message
            if let error = settingsManager.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.bottom, 6)
            }

            // Sliders
            VStack(spacing: 14) {
                SliderRow(
                    label: "UI Scale",
                    icon: "uiwindow.split.2x1",
                    value: $settingsManager.zoomLevel,
                    range: -1.0...3.0,
                    step: 0.25,
                    format: "%.2f"
                )
                .onChange(of: settingsManager.zoomLevel) { settingsManager.save() }

                SliderRow(
                    label: "Editor",
                    icon: "doc.text",
                    value: $editorDouble,
                    range: 8...36,
                    step: 1,
                    format: "%.0f"
                )
                .onChange(of: editorDouble) {
                    settingsManager.editorFontSize = Int(editorDouble)
                    settingsManager.save()
                }

                SliderRow(
                    label: "Terminal",
                    icon: "terminal",
                    value: $terminalDouble,
                    range: 8...36,
                    step: 1,
                    format: "%.0f"
                )
                .onChange(of: terminalDouble) {
                    settingsManager.terminalFontSize = Int(terminalDouble)
                    settingsManager.save()
                }
            }

            Divider()
                .padding(.vertical, 10)

            // Presets
            HStack(spacing: 8) {
                presetButton("Compact", preset: .compact)
                Button("Default") {
                    settingsManager.restoreOriginal()
                    syncFromManager()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                presetButton("Relaxed", preset: .relaxed)
            }

            Divider()
                .padding(.vertical, 10)

            // Settings toggles
            VStack(spacing: 6) {
                HStack {
                    Text("Show in Dock")
                        .font(.caption)
                    Spacer()
                    Toggle("", isOn: $showInDock)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .onChange(of: showInDock) { _, newValue in
                            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        }
                }
                HStack {
                    Text("Start at login")
                        .font(.caption)
                    Spacer()
                    Toggle("", isOn: $startAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .onChange(of: startAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                startAtLogin = !newValue
                            }
                        }
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Footer
            HStack {
                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear { syncFromManager() }
        .onChange(of: settingsManager.editorFontSize) { syncFromManager() }
        .onChange(of: settingsManager.terminalFontSize) { syncFromManager() }
    }

    private func presetButton(_ label: String, preset: FontSettings) -> some View {
        Button(label) {
            settingsManager.apply(preset)
            syncFromManager()
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
    }

    private func syncFromManager() {
        editorDouble = Double(settingsManager.editorFontSize)
        terminalDouble = Double(settingsManager.terminalFontSize)
    }
}
