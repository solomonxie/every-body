import SwiftUI

/// Settings as the last section of the home page.
struct SettingsSection: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("Settings", "设置")).font(.title3.weight(.bold))
            VStack(alignment: .leading, spacing: 12) {
                row(settings.t("Language", "语言")) {
                    Picker("", selection: $settings.names) {
                        Text("English").tag(NameMode.en)
                        Text("中文").tag(NameMode.zh)
                    }
                    .pickerStyle(.segmented)
                }
                row(settings.t("Person", "人群")) {
                    Picker("", selection: $settings.age) {
                        ForEach(AgeGroup.allCases, id: \.self) { Text(settings.zh ? $0.label.zh : $0.label.en.components(separatedBy: " ")[0]).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                row(settings.t("Sex", "性别")) {
                    Picker("", selection: $settings.female) {
                        Text(settings.t("Male", "男")).tag(false)
                        Text(settings.t("Female", "女")).tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                if settings.female && settings.age == .adult {
                    Toggle(settings.t("Pregnant", "怀孕"), isOn: $settings.pregnant)
                }
                Toggle(settings.t("White 3D background", "3D 白色背景"), isOn: $settings.whiteBackground)
                Toggle(settings.t("Auto-rotate on open", "打开时自动旋转"), isOn: $settings.autoRotate)
            }
            .font(.subheadline)
            .padding(12)
            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.t("Body Atlas is for learning, not medical advice. Reflex and acupoint effects describe traditional practice, not proven treatment. In an emergency call 120 / 911.",
                                "本应用仅供学习，不构成医疗建议。穴位与反射区功效为传统说法。紧急情况请拨打 120。"))
                Text(settings.t("Ear points: GB/T 13734-2008. Acupoints: WHO Standard Acupuncture Point Locations (2008). First aid: ILCOR / Red Cross. All drawings are schematic.",
                                "耳穴：GB/T 13734-2008。穴位：WHO 标准针灸穴位定位（2008）。急救：ILCOR / 红十字会。所有图均为示意图。"))
                    .foregroundStyle(.secondary)
                Text("\(settings.t("Version", "版本")) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
    }

    private func row(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}
