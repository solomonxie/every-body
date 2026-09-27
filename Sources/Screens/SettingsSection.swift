import SwiftUI

/// Settings as the last section of the home page.
struct SettingsSection: View {
    @Environment(Settings.self) private var settings
    @State private var showSources = false
    @State private var showCredits = false

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
                divider
                VStack(alignment: .leading, spacing: Space.s) {
                    label("person.fill", .brandFill, settings.t("Person", "人群"))
                    Picker(settings.t("Person", "人群"), selection: $settings.age) {
                        ForEach(AgeGroup.allCases, id: \.self) {
                            Text(settings.zh ? $0.label.zh : $0.label.en.components(separatedBy: " ")[0]).tag($0)
                        }
                    }
                }
                .padding(.vertical, Space.m)
                divider
                row("figure.dress.line.vertical.figure", .pink, settings.t("Sex", "性别")) {
                    Picker(settings.t("Sex", "性别"), selection: $settings.female) {
                        Text(settings.t("Male", "男")).tag(false)
                        Text(settings.t("Female", "女")).tag(true)
                    }
                    .fixedSize()
                }
                if settings.female && settings.age == .adult {
                    divider
                    row("figure.and.child.holdinghands", Color(hex: "#C77DA0"), settings.t("Pregnant", "怀孕")) {
                        Toggle(settings.t("Pregnant", "怀孕"), isOn: $settings.pregnant).labelsHidden()
                    }
                }
            }
            .adaptivePickerStyle()
            .animation(.snappy, value: settings.female && settings.age == .adult)

            Eyebrow(settings.t("3D viewer", "3D 视图")).padding(.horizontal, Space.xs).padding(.top, Space.s)
            group {
                row("paintpalette.fill", .orange, settings.t("Appearance", "外貌")) {
                    Picker(settings.t("Appearance", "外貌"), selection: $settings.heritage) {
                        ForEach(Heritage.allCases, id: \.self) { Text(settings.t($0.label)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                divider
                row("tshirt.fill", Color(hex: "#6F9BC9"), settings.t("Show underwear", "显示内衣")) {
                    Toggle(settings.t("Show underwear", "显示内衣"), isOn: $settings.showUnderwear).labelsHidden()
                }
                divider
                row("square.fill", .gray, settings.t("White background", "白色背景")) {
                    Toggle(settings.t("White background", "白色背景"), isOn: $settings.whiteBackground).labelsHidden()
                }
                divider
                row("arrow.trianglehead.2.clockwise.rotate.90", .teal, settings.t("Auto-rotate on open", "打开时自动旋转")) {
                    Toggle(settings.t("Auto-rotate on open", "打开时自动旋转"), isOn: $settings.autoRotate).labelsHidden()
                }
                divider
                Button { showCredits = true } label: {
                    HStack(spacing: Space.m) {
                        label("doc.text", .indigo, settings.t("Credits & licences", "致谢与许可"))
                        Spacer(minLength: Space.s)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, Space.m)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showCredits) { CreditsView() }
            }

            about.padding(.top, Space.s)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Label {
                Text(settings.t("For learning, not medical advice. In an emergency call 120 / 911.",
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
