import SwiftUI

struct CandidateCard: View {
    var candidate: CandidateResult
    var selected: Bool
    var select: () -> Void
    var apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(candidate.action.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(candidate.costUSD.map { String(format: "$%.4f", $0) } ?? "$—")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(candidate.diff)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 120)
            HStack {
                Button("Select") { select() }
                    .buttonStyle(.borderless)
                    .pointingCursor()
                Spacer()
                Button("Apply") { apply() }
                    .buttonStyle(.borderless)
                    .pointingCursor()
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { select() }
        .pointingCursor()
    }
}
