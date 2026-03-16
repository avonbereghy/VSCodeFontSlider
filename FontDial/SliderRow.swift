import SwiftUI

struct SliderRow: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 30, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}
