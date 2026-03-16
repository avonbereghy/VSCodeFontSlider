import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("FontDial.showInDock") private var showInDock = false
    @AppStorage("FontDial.startAtLogin") private var startAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 48))
                    .foregroundStyle(.primary)

                Text("FontDial")
                    .font(.title2.bold())

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                // When hiding from dock, make sure we don't lose focus entirely
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
                                // Revert on failure
                                startAtLogin = !newValue
                            }
                        }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(width: 340, height: 280)
        .onAppear {
            // Sync start-at-login state with system
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
