import SwiftUI

struct Pill: View {
    let label: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Color.brand.opacity(0.25) : Color.secondary.opacity(0.12), in: .capsule)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

struct PillRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content }.padding(.horizontal, 16)
        }
    }
}
