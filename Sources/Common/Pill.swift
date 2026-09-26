import SwiftUI

/// Selectable chip: 36 pt capsule inside a 44 pt hit area.
struct Pill: View {
    let label: String
    var selected = false
    var symbol: String? = nil
    /// colour dot before the label (layers, groups)
    var dot: Color? = nil
    var warn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs + 2) {
                if warn {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.caution).imageScale(.small)
                }
                if let symbol { Image(systemName: symbol).imageScale(.small) }
                if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
                Text(label).lineLimit(1)
            }
            .font(.subheadline.weight(selected ? .semibold : .medium))
            .foregroundStyle(selected ? Color.brand : .primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(selected ? Color.brand.opacity(0.16) : Color.fill, in: .capsule)
            .overlay(Capsule().strokeBorder(selected ? Color.brand.opacity(0.55) : .clear, lineWidth: 1))
            .padding(.vertical, (minTap - 36) / 2)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct PillRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) { content }.padding(.horizontal, Space.l)
        }
    }
}
