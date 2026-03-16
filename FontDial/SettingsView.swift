import SwiftUI
import ServiceManagement

struct SettingsView: View {
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

            // Settings
            VStack(spacing: 0) {
                settingsRow("Show icon in dock") {
                    Toggle("", isOn: $showInDock)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: showInDock) { _, newValue in
                            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                            if !newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    NSApp.activate(ignoringOtherApps: true)
                                }
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
        .frame(width: 340, height: 320)
        .onAppear {
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
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
}
