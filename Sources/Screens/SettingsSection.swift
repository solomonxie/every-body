import SwiftUI

/// Settings as the last section of the home page.
struct SettingsSection: View {
    @Environment(Settings.self) private var settings
    @State private var showSources = false

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(settings.t("Settings", "设置"))
            group {
                row("globe", .blue, settings.t("Language", "语言")) {
                    Picker(settings.t("Language", "语言"), selection: $settings.names) {
                        Text("English").tag(NameMode.en)
                        Text("中文").tag(NameMode.zh)
                    }
                    .fixedSize()
                }
            }
            .adaptivePickerStyle()

            about.padding(.top, Space.s)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Label {
                Text(settings.t("For learning, not medical advice. In an emergency call 911.",
                                "仅供学习，不构成医疗建议。紧急情况请拨打 120。"))
            } icon: {
                Image(systemName: "stethoscope").foregroundStyle(Color.emergency)
            }
            .font(.footnote)
            HStack(spacing: Space.m) {
                Button {
                    showSources = true
                } label: {
                    Label(settings.t("Sources", "资料来源"), systemImage: "info.circle")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: minTap)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showSources) {
                    Text(settings.t("Reflex and acupoint effects describe traditional practice, not proven treatment.\n\nEar points: GB/T 13734-2008. Acupoints: WHO Standard Acupuncture Point Locations (2008). First aid: ILCOR / Red Cross. All drawings are schematic.",
                                    "穴位与反射区功效为传统说法，未经证实。\n\n耳穴：GB/T 13734-2008。穴位：WHO 标准针灸穴位定位（2008）。急救：ILCOR / 红十字会。所有图均为示意图。"))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Space.l)
                        .frame(idealWidth: 320)
                        .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Text("\(settings.t("Version", "版本")) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Space.xs)
    }

    private var divider: some View { Divider().padding(.leading, 30 + Space.m) }

    private func group(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, Space.l)
            .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    private func label(_ symbol: String, _ color: Color, _ title: String) -> some View {
        HStack(spacing: Space.m) {
            IconBadge(symbol: symbol, color: color)
            Text(title)
        }
    }

    private func row(_ symbol: String, _ color: Color, _ title: String, @ViewBuilder _ control: () -> some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.m) {
                label(symbol, color, title)
                Spacer(minLength: Space.s)
                control()
            }
            VStack(alignment: .leading, spacing: Space.s) {
                label(symbol, color, title)
                control()
            }
        }
        .frame(minHeight: minTap)
        .padding(.vertical, Space.s)
    }
}
