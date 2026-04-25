import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    @State private var editorDouble: Double = 14
    @State private var terminalDouble: Double = 14
    @AppStorage("FontDial.showInMenuBar") private var showInMenuBar = true
    @AppStorage("FontDial.showInDock") private var showInDock = false
    @AppStorage("FontDial.startAtLogin") private var startAtLogin = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            // About section
            VStack(spacing: 8) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                } else {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 48))
                        .foregroundStyle(.primary)
                }

                Text("FontDial")
                    .font(.title2.bold())

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\u{00A9} 2026 Andrew von Bereghy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            VStack(spacing: 14) {
                if let error = settingsManager.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                settingsRow("Show in menu bar") {
                    Toggle("", isOn: $showInMenuBar)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: showInMenuBar) { _, newValue in
                            if !newValue && !showInDock {
                                showInDock = true
                            }
                        }
                }

                Divider().padding(.horizontal, 16)

                settingsRow("Show in Dock") {
                    Toggle("", isOn: $showInDock)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: showInDock) { _, newValue in
                            if !newValue && !showInMenuBar {
                                showInMenuBar = true
                            }
                        }
                }

                Divider().padding(.horizontal, 16)

                settingsRow("Start at login") {
                    Toggle("", isOn: $startAtLogin)
                        .toggleStyle(.switch)
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)

            // TODO: Revisit paid upgrade flow later — not charging yet
            // Button {
            //     showUpgradeSheet = true
            // } label: {
            //     Label("Upgrade to Basic ($12)", systemImage: "star.fill")
            //         .frame(maxWidth: .infinity)
            //         .padding(.vertical, 6)
            // }
            // .buttonStyle(.borderedProminent)
            // .controlSize(.regular)
            // .padding(.horizontal, 20)
            // .padding(.top, 16)

            // GitHub link
            HStack {
                Spacer()
                Link("GitHub", destination: URL(string: "https://github.com/avonbereghy/VSCodeFontSlider")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 12)

            Spacer()
        }
        .frame(width: 360, height: 520)
        .onAppear {
            syncFromManager()
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onChange(of: settingsManager.editorFontSize) { syncFromManager() }
        .onChange(of: settingsManager.terminalFontSize) { syncFromManager() }
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
