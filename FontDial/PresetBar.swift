import SwiftUI

/// Applies, saves, overrides, renames and resets presets. Shared by the popover
/// and the Settings window; `isCompact` trims it for the popover's width.
struct PresetBar: View {
    @ObservedObject var settingsManager: SettingsManager
    var isCompact: Bool = false
    /// Called after a preset is applied so the host view can resync its sliders.
    var onApply: () -> Void = {}

    @State private var draftName = ""
    @State private var renamingPresetID: String?
    @State private var isEditingName = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Presets")
                    .font(isCompact ? .caption : .subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    beginSaving()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Save the current values as a new preset")

                Menu {
                    manageMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .help("Manage presets")
            }

            PresetFlowLayout(spacing: 6) {
                ForEach(settingsManager.presets) { preset in
                    Button(preset.name) {
                        settingsManager.apply(preset)
                        onApply()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .contextMenu { actions(for: preset) }
                    .help(summary(of: preset))
                }
            }

            if isEditingName {
                nameEditor
            }
        }
    }

    // MARK: - Name Editor

    private var nameEditor: some View {
        HStack(spacing: 6) {
            TextField("Preset name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .focused($nameFieldFocused)
                .onSubmit { commitName() }

            Button(renamingPresetID == nil ? "Save" : "Rename") { commitName() }
                .controlSize(.small)
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Cancel") { cancelEditing() }
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    private func beginSaving() {
        renamingPresetID = nil
        draftName = ""
        isEditingName = true
        nameFieldFocused = true
    }

    private func beginRenaming(_ preset: Preset) {
        renamingPresetID = preset.id
        draftName = preset.name
        isEditingName = true
        nameFieldFocused = true
    }

    private func commitName() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let id = renamingPresetID, let preset = settingsManager.presets.first(where: { $0.id == id }) {
            settingsManager.renamePreset(preset, to: name)
        } else {
            settingsManager.savePreset(named: name)
        }
        cancelEditing()
    }

    private func cancelEditing() {
        isEditingName = false
        nameFieldFocused = false
        renamingPresetID = nil
        draftName = ""
    }

    // MARK: - Menus

    @ViewBuilder
    private func actions(for preset: Preset) -> some View {
        Button("Apply") {
            settingsManager.apply(preset)
            onApply()
        }

        Divider()

        Button("Update to Current Values") {
            settingsManager.overwritePreset(preset)
        }

        if preset.isBuiltIn {
            Button("Reset to Built-in") {
                settingsManager.resetPreset(preset)
            }
            .disabled(!settingsManager.isOverridden(preset))
        } else {
            Button("Rename\u{2026}") { beginRenaming(preset) }
            Divider()
            Button("Delete", role: .destructive) {
                settingsManager.deletePreset(preset)
            }
        }
    }

    @ViewBuilder
    private var manageMenu: some View {
        Button("Save Current Values as Preset\u{2026}") { beginSaving() }

        Divider()

        ForEach(settingsManager.presets) { preset in
            Menu(preset.name) { actions(for: preset) }
        }

        Divider()

        Button("Reset All Built-in Presets") {
            settingsManager.resetAllBuiltInPresets()
        }
        .disabled(!settingsManager.hasOverriddenBuiltIns)

        Button("Restore Original VS Code Settings") {
            settingsManager.restoreOriginal()
            onApply()
        }
        .disabled(!settingsManager.canRestoreOriginal)
    }

    /// Shown on hover so a preset's values are visible without applying it.
    private func summary(of preset: Preset) -> String {
        let s = preset.settings
        let scale = s.zoomLevel == s.zoomLevel.rounded()
            ? String(format: "%.0f", s.zoomLevel)
            : String(format: "%.2f", s.zoomLevel)
        let values = "UI \(scale) · Editor \(s.editorFontSize) · Terminal \(s.terminalFontSize) · Chat \(s.chatFontSize) · Chat Code \(s.chatEditorFontSize)"
        return settingsManager.isOverridden(preset) ? "\(values)  (customized)" : values
    }
}

/// Wraps preset chips onto as many rows as the available width needs.
struct PresetFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let width = row.indices.isEmpty ? size.width : row.width + spacing + size.width

            if width > maxWidth && !row.indices.isEmpty {
                rows.append(row)
                row = Row(indices: [index], width: size.width, height: size.height)
            } else {
                row.indices.append(index)
                row.width = width
                row.height = max(row.height, size.height)
            }
        }

        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
