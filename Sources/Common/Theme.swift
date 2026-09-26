import SwiftUI

/// Spacing scale (pt).
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii.
enum Radius {
    static let small: CGFloat = 8
    static let tile: CGFloat = 12
    static let card: CGFloat = 16
    static let sheet: CGFloat = 22
}

/// Minimum hit target.
let minTap: CGFloat = 44

extension Color {
    /// grouped page behind cards
    static let page = Color(uiColor: .systemGroupedBackground)
    /// card on a grouped page
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    /// quiet fill for chips and secondary buttons
    static let fill = Color(uiColor: .tertiarySystemFill)
    static let hairline = Color(uiColor: .separator)

    static let caution = Color(light: "#B5462E", dark: "#FF8C73")
    static let cautionFill = Color(light: "#FBE3DC", dark: "#3D211B")
    static let success = Color(light: "#2E9E5B", dark: "#4FCB82")
    static let emergency = Color(light: "#D8434B", dark: "#E5575E")
    static let note = Color(light: "#2B2250", dark: "#D9D0F2")
    static let noteFill = Color(light: "#EDE8F8", dark: "#2A2440")
}

/// Card surface: padded, rounded, adaptive.
struct CardModifier: ViewModifier {
    var padding: CGFloat = Space.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = Space.l) -> some View { modifier(CardModifier(padding: padding)) }
}

/// Section title with optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.s)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}

/// Small grey caps label above a group.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Coloured rounded square behind an SF Symbol — row and header icons.
struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Filled brand capsule, full width.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .brandFill
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: minTap + 6)
            .padding(.horizontal, Space.l)
            .background(color.opacity(enabled ? 1 : 0.4), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Quiet tinted capsule.
struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(enabled ? Color.brand : Color.secondary)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minTap + 6)
            .padding(.horizontal, Space.l)
            .background(Color.brand.opacity(enabled ? 0.14 : 0.06), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Pressed feedback for custom-drawn tappable surfaces (tiles, rows).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// List-row press highlight.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemFill) : .clear)
    }
}

/// Segmented, or a menu once Dynamic Type is too large for segments.
struct AdaptivePickerStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        if typeSize.isAccessibilitySize { content.pickerStyle(.menu) } else { content.pickerStyle(.segmented) }
    }
}

extension View {
    func adaptivePickerStyle() -> some View { modifier(AdaptivePickerStyle()) }
}
